import Foundation
import HealthKit
import CoreMotion

/// Runs an Apple Watch strength workout session using every sensor the Watch offers apps during a workout:
/// optical heart rate (live, average, peak), active and resting energy from the Watch's own calorie model,
/// and the accelerometer and gyroscope to count reps. Keeps the app active and saves to Apple Health.
@MainActor
final class WatchWorkoutManager: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    @Published private(set) var isRunning = false
    @Published private(set) var heartRate: Double = 0
    @Published private(set) var averageHeartRate: Double = 0
    @Published private(set) var maxHeartRate: Double = 0
    @Published private(set) var activeCalories: Double = 0
    @Published private(set) var restingCalories: Double = 0
    /// Reps the motion sensors counted since the last `resetReps()`.
    @Published private(set) var countedReps = 0

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private let reps = RepCounter()

    struct WorkoutResult {
        var calories: Double?
        var averageHeartRate: Double?
        var maxHeartRate: Double?
        var saved: Bool
    }

    override init() {
        super.init()
        reps.onRep = { [weak self] n in Task { @MainActor in self?.countedReps = n } }
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let share: Set<HKSampleType> = [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned),
                                        HKQuantityType(.basalEnergyBurned)]
        let read: Set<HKObjectType> = [HKObjectType.workoutType(), HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned),
                                       HKQuantityType(.basalEnergyBurned), HKQuantityType(.restingHeartRate),
                                       HKQuantityType(.heartRateVariabilitySDNN), HKQuantityType(.oxygenSaturation),
                                       HKQuantityType(.respiratoryRate), HKQuantityType(.vo2Max)]
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
            let source = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            for type in [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned), HKQuantityType(.basalEnergyBurned)] {
                source.enableCollection(for: type, predicate: nil)
            }
            newBuilder.dataSource = source
            newSession.delegate = self
            newBuilder.delegate = self
            session = newSession
            builder = newBuilder
            let start = Date()
            newSession.startActivity(with: start)
            try await newBuilder.beginCollection(at: start)
            isRunning = true
            reps.start()
        } catch {
            session = nil
            builder = nil
            isRunning = false
        }
    }

    /// Start counting reps from zero, e.g. when a new set begins.
    func resetReps() {
        reps.reset()
        countedReps = 0
    }

    func end() async -> WorkoutResult {
        reps.stop()
        guard let s = session, let b = builder else {
            return WorkoutResult(calories: nil, averageHeartRate: nil, maxHeartRate: nil, saved: false)
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
                                   maxHeartRate: maxHeartRate > 0 ? maxHeartRate : nil,
                                   saved: saved)
        session = nil
        builder = nil
        isRunning = false
        heartRate = 0
        averageHeartRate = 0
        maxHeartRate = 0
        activeCalories = 0
        restingCalories = 0
        countedReps = 0
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
        let peak = hrStats?.maximumQuantity()?.doubleValue(for: bpm)
        let kcal = workoutBuilder.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
        let basal = workoutBuilder.statistics(for: HKQuantityType(.basalEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
        Task { @MainActor in
            if let current { self.heartRate = current }
            if let average { self.averageHeartRate = average }
            if let peak { self.maxHeartRate = peak }
            if let kcal { self.activeCalories = kcal }
            if let basal { self.restingCalories = basal }
        }
    }
}

/// Counts reps from wrist motion: each rep is one push-and-return of the arm, seen as a peak in
/// smoothed acceleration (gravity removed) followed by a dip, with at least 0.7 s between reps.
final class RepCounter: @unchecked Sendable {
    var onRep: ((Int) -> Void)?

    private let motion = CMMotionManager()
    private let queue = OperationQueue()
    private var count = 0
    private var smoothed = 0.0
    private var armed = true
    private var lastRep = Date.distantPast

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        queue.maxConcurrentOperationCount = 1
        motion.deviceMotionUpdateInterval = 1.0 / 50
        motion.startDeviceMotionUpdates(to: queue) { [weak self] data, _ in
            guard let self, let a = data?.userAcceleration else { return }
            let magnitude = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
            self.smoothed += (magnitude - self.smoothed) * 0.15
            let now = Date()
            if self.armed, self.smoothed > 0.16, now.timeIntervalSince(self.lastRep) > 0.7 {
                self.armed = false
                self.lastRep = now
                self.count += 1
                self.onRep?(self.count)
            } else if !self.armed, self.smoothed < 0.06 {
                self.armed = true
            }
        }
    }

    func reset() {
        queue.addOperation { [weak self] in
            self?.count = 0
            self?.armed = true
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        reset()
    }
}
