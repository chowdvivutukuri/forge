import Foundation
import HealthKit

@MainActor
final class HealthManager {
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Why the last connection attempt failed, in the words HealthKit gave (nil when it worked).
    private(set) var lastError: String?

    private var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned), HKQuantityType(.bodyMass),
         HKQuantityType(.distanceWalkingRunning)]
    }
    /// Everything the Watch measures that helps with calories and recovery.
    private var readTypes: Set<HKObjectType> {
        [HKObjectType.workoutType(), HKQuantityType(.heartRate), HKQuantityType(.restingHeartRate),
         HKQuantityType(.heartRateVariabilitySDNN), HKQuantityType(.vo2Max), HKQuantityType(.respiratoryRate),
         HKQuantityType(.oxygenSaturation), HKQuantityType(.bodyMass), HKQuantityType(.height),
         HKQuantityType(.activeEnergyBurned), HKQuantityType(.basalEnergyBurned), HKQuantityType(.stepCount),
         HKCharacteristicType(.dateOfBirth), HKCharacteristicType(.biologicalSex)]
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable else {
            lastError = "Apple Health isn't available on this device."
            return false
        }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Whether Forge may write workouts. (iOS never reveals whether reading was allowed.)
    var canSaveWorkouts: Bool { store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized }

    // MARK: Sensor readings from Apple Health (recorded by the Watch)

    /// Active calories other apps and devices (mainly Apple Watch) recorded between two times, leaving out Forge's own.
    func measuredActiveEnergy(start: Date, end: Date) async -> Double? {
        let notForge = NSCompoundPredicate(notPredicateWithSubpredicate: HKQuery.predicateForObjects(from: HKSource.default()))
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate), notForge])
        return await withCheckedContinuation { continuation in
            let q = HKStatisticsQuery(quantityType: HKQuantityType(.activeEnergyBurned), quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: .kilocalorie()))
            }
            store.execute(q)
        }
    }

    /// Average and peak heart rate between two times.
    func heartRate(start: Date, end: Date) async -> (average: Double, max: Double)? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let bpm = HKUnit.count().unitDivided(by: .minute())
        return await withCheckedContinuation { continuation in
            let q = HKStatisticsQuery(quantityType: HKQuantityType(.heartRate), quantitySamplePredicate: predicate,
                                      options: [.discreteAverage, .discreteMax]) { _, stats, _ in
                guard let avg = stats?.averageQuantity()?.doubleValue(for: bpm),
                      let peak = stats?.maximumQuantity()?.doubleValue(for: bpm) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: (avg, peak))
            }
            store.execute(q)
        }
    }

    var ageYears: Double? {
        guard let dob = try? store.dateOfBirthComponents(), let date = Calendar.current.date(from: dob) else { return nil }
        return Date().timeIntervalSince(date) / (365.25 * 86400)
    }

    var healthSex: Sex? {
        switch (try? store.biologicalSex())?.biologicalSex {
        case .male: return .male
        case .female: return .female
        default: return nil
        }
    }

    /// Calories from average heart rate (Keytel et al. 2005), for when the Watch didn't log energy itself.
    static func heartRateCalories(averageBPM hr: Double, minutes: Double, kg: Double, age: Double, female: Bool) -> Double {
        let perMinute = female
            ? (-20.4022 + 0.4472 * hr - 0.1263 * kg + 0.074 * age) / 4.184
            : (-55.0969 + 0.6309 * hr + 0.1988 * kg + 0.2017 * age) / 4.184
        return max(0, perMinute * minutes)
    }

    static func estimatedCalories(start: Date, end: Date, bodyMassKg: Double) -> Double {
        // Strength training is roughly 5 METs.
        5.0 * bodyMassKg * max(0, end.timeIntervalSince(start)) / 3600
    }

    /// Saves a strength workout. Pass nil for kcal when the Watch already recorded the energy, so it isn't counted twice.
    func saveStrengthWorkout(start: Date, end: Date, kcal: Double?) async -> Bool {
        guard isAvailable else { return false }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        do {
            try await builder.beginCollection(at: start)
            if let kcal, kcal > 0 {
                let energy = HKQuantitySample(type: HKQuantityType(.activeEnergyBurned),
                                              quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                                              start: start, end: end)
                try await builder.addSamples([energy])
            }
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
