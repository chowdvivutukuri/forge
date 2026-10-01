import Foundation
import HealthKit

/// Runs an Apple Watch strength workout session: live heart rate, calories,
/// keeps the app active during the workout, and saves to Apple Health.
@MainActor
final class WatchWorkoutManager: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    @Published private(set) var isRunning = false
    @Published private(set) var heartRate: Double = 0
    @Published private(set) var averageHeartRate: Double = 0
    @Published private(set) var activeCalories: Double = 0

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    struct WorkoutResult {
        var calories: Double?
        var averageHeartRate: Double?
        var saved: Bool
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let share: Set<HKSampleType> = [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned)]
        let read: Set<HKObjectType> = [HKObjectType.workoutType(), HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]
        try? await healthStore.requestAuthorization(toShare: share, read: read)
    }

    func start() async {
        guard session == nil else { return }
        await requestAuthorization()
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor
        do {
            let newSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let newBuilder = newSession.associatedWorkoutBuilder()
            newBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            newSession.delegate = self
            newBuilder.delegate = self
            session = newSession
            builder = newBuilder
            let start = Date()
            newSession.startActivity(with: start)
            try await newBuilder.beginCollection(at: start)
            isRunning = true
        } catch {
            session = nil
            builder = nil
            isRunning = false
        }
    }

    func end() async -> WorkoutResult {
        guard let s = session, let b = builder else {
            return WorkoutResult(calories: nil, averageHeartRate: nil, saved: false)
        }
        s.end()
        var saved = false
        do {
            try await b.endCollection(at: Date())
            _ = try await b.finishWorkout()
            saved = true
        } catch {}
        let result = WorkoutResult(calories: activeCalories > 0 ? activeCalories : nil,
                            averageHeartRate: averageHeartRate > 0 ? averageHeartRate : nil,
                            saved: saved)
        session = nil
        builder = nil
        isRunning = false
        heartRate = 0
        averageHeartRate = 0
        activeCalories = 0
        return result
    }

    // MARK: Delegates

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState, date: Date) {
        let running = toState == .running
        Task { @MainActor in self.isRunning = running }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let hrStats = workoutBuilder.statistics(for: HKQuantityType(.heartRate))
        let current = hrStats?.mostRecentQuantity()?.doubleValue(for: bpm)
        let average = hrStats?.averageQuantity()?.doubleValue(for: bpm)
        let kcal = workoutBuilder.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
        Task { @MainActor in
            if let current { self.heartRate = current }
            if let average { self.averageHeartRate = average }
            if let kcal { self.activeCalories = kcal }
        }
    }
}
