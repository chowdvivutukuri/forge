import Foundation
import HealthKit

@MainActor
final class HealthManager {
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned), HKQuantityType(.bodyMass),
         HKQuantityType(.distanceWalkingRunning)]
    }
    private var readTypes: Set<HKObjectType> {
        [HKObjectType.workoutType(), HKQuantityType(.heartRate), HKQuantityType(.bodyMass), HKQuantityType(.activeEnergyBurned)]
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            return true
        } catch {
            return false
        }
    }

    static func estimatedCalories(start: Date, end: Date, bodyMassKg: Double) -> Double {
        // Strength training is roughly 5 METs.
        5.0 * bodyMassKg * max(0, end.timeIntervalSince(start)) / 3600
    }

    func saveStrengthWorkout(start: Date, end: Date, bodyMassKg: Double) async -> Bool {
        guard isAvailable else { return false }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        do {
            try await builder.beginCollection(at: start)
            let kcal = Self.estimatedCalories(start: start, end: end, bodyMassKg: bodyMassKg)
            let energy = HKQuantitySample(type: HKQuantityType(.activeEnergyBurned),
                                          quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                                          start: start, end: end)
            try await builder.addSamples([energy])
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
            return true
        } catch {
            return false
        }
    }

    /// Saves a treadmill or elliptical block as its own workout.
    func saveCardioWorkout(exerciseID: String, start: Date, end: Date, kcal: Double, distanceMeters: Double?) async -> Bool {
        guard isAvailable, end > start else { return false }
        let config = HKWorkoutConfiguration()
        let running = exerciseID == "tm_run" || exerciseID == "tm_intervals"
        config.activityType = Cardio.isTreadmill(exerciseID) ? (running ? .running : .walking) : .elliptical
        config.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        do {
            try await builder.beginCollection(at: start)
            var samples: [HKSample] = [
                HKQuantitySample(type: HKQuantityType(.activeEnergyBurned),
                                 quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal), start: start, end: end)
            ]
            if let meters = distanceMeters, meters > 0 {
                samples.append(HKQuantitySample(type: HKQuantityType(.distanceWalkingRunning),
                                                quantity: HKQuantity(unit: .meter(), doubleValue: meters), start: start, end: end))
            }
            try await builder.addSamples(samples)
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
            return true
        } catch {
            return false
        }
    }

    func saveBodyMass(kg: Double, date: Date) async {
        guard isAvailable else { return }
        let sample = HKQuantitySample(type: HKQuantityType(.bodyMass),
                                      quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
                                      start: date, end: date)
        try? await store.save(sample)
    }

    func latestBodyMassKg() async -> Double? {
        guard isAvailable else { return nil }
        let type = HKQuantityType(.bodyMass)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let kg = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            store.execute(query)
        }
    }
}
