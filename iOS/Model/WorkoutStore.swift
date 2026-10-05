import Foundation
import UIKit
import SwiftUI

@MainActor
final class WorkoutStore: ObservableObject {
    @Published var settings: UserSettings {
        didSet {
            if oldValue.abhiMode != settings.abhiMode { applyLook(settings.abhiMode) }
            stateChanged(pushToWatch: true)
        }
    }
    @Published private(set) var history: [Workout] { didSet { stateChanged(pushToWatch: false) } }
    @Published var current: Workout? { didSet { stateChanged(pushToWatch: true) } }
    @Published private(set) var weighIns: [WeighIn] { didSet { stateChanged(pushToWatch: false) } }
    /// Which tab is showing (not saved).
    @Published var selectedTab: AppTab = .workout

    let health = HealthManager()
    let connectivity = PhoneConnectivity()
    let backup = CloudBackup()

    struct Saved: Codable {
        var settings: UserSettings
        var history: [Workout]
        var current: Workout?
        var weighIns: [WeighIn]?
        var savedAt: Date?
    }

    private let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("forge.json")

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            settings = saved.settings
            history = saved.history
            current = saved.current
            weighIns = saved.weighIns ?? []
        } else {
            settings = UserSettings()
            history = []
            current = nil
            weighIns = []
        }
        ForgeColors.setAbhiMode(settings.abhiMode)
        AbhiAppearance.apply(settings.abhiMode)
        connectivity.onWorkoutUpdate = { [weak self] w in self?.receiveFromWatch(w, finished: false) }
        connectivity.onWorkoutFinished = { [weak self] w in self?.receiveFromWatch(w, finished: true) }
        connectivity.onActivated = { [weak self] in
            guard let self else { return }
            self.connectivity.push(current: self.current, settings: self.settings)
        }
        connectivity.activate()
        // Ask for Apple Health once, so heart rate and Watch calories flow in without a trip to Settings.
        if !settings.healthEnabled, !UserDefaults.standard.bool(forKey: "forge.healthAsked") {
            UserDefaults.standard.set(true, forKey: "forge.healthAsked")
            Task { _ = await connectHealth() }
        }
    }

    // MARK: Persistence

    private func snapshot() -> Data? {
        let saved = Saved(settings: settings, history: history, current: current, weighIns: weighIns, savedAt: Date())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(saved)
    }

    private func stateChanged(pushToWatch: Bool) {
        let saved = Saved(settings: settings, history: history, current: current, weighIns: weighIns, savedAt: Date())
        if let data = try? JSONEncoder().encode(saved) {
            try? data.write(to: fileURL, options: .atomic)
        }
        if let data = snapshot() { backup.scheduleBackup(data) }
        if pushToWatch { connectivity.push(current: current, settings: settings) }
    }

    /// Abhi mode: purple everything, including the home-screen icon.
    private func applyLook(_ purple: Bool) {
        ForgeColors.setAbhiMode(purple)
        AbhiAppearance.apply(purple)
        let app = UIApplication.shared
        guard app.supportsAlternateIcons else { return }
        let wanted: String? = purple ? "AppIconPurple" : nil
        if app.alternateIconName != wanted {
            app.setAlternateIconName(wanted) { _ in }
        }
    }

    func backupNow() {
        if let data = snapshot() { backup.writeNow(data) }
    }

    /// Replaces all data with a backup from iCloud Drive.
    func restoreFromBackup() -> Bool {
        guard let data = backup.readBackup() else { return false }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let saved = try? decoder.decode(Saved.self, from: data) else {
            backup.lastError = "The backup file couldn't be read."
            return false
        }
        settings = saved.settings
        history = saved.history
        current = saved.current
        weighIns = saved.weighIns ?? []
        return true
    }

    func eraseAll() {
        history = []
        current = nil
        weighIns = []
        settings = UserSettings()
    }

    // MARK: Derived

    var recovery: [Muscle: Double] { RecoveryEngine.recovery(history: history) }
    var latestWeightKg: Double? { weighIns.max { $0.date < $1.date }?.kg }
    var startWeightKg: Double? { weighIns.min { $0.date < $1.date }?.kg }
    var generator: WorkoutGenerator { WorkoutGenerator(settings: settings, history: history, bodyWeightKg: latestWeightKg) }
    var programDayIndex: Int {
        let n = max(1, settings.schedule.count)
        return ((settings.programDay % n) + n) % n
    }
    var needsWeighIn: Bool {
        guard let last = weighIns.map(\.date).max() else { return true }
        return Date().timeIntervalSince(last) > 7 * 86_400
    }

    // MARK: Workout actions

    /// Generates the next day of the program.
    func startNextProgramDay() { startPlannedDay(programDayIndex) }

    /// Starts the same workout the Program tab shows for that day.
    func startPlannedDay(_ index: Int) {
        let preview = generator.programPreview()
        if preview.indices.contains(index) {
            start(planned: preview[index])
        } else {
            startProgramDay(index)
        }
    }

    /// Starts exactly the workout shown on the Program tab, with weights refreshed from your real history,
    /// and switches to the Workout tab.
    func start(planned: Workout) {
        var w = planned
        w.id = UUID()
        w.createdAt = Date()
        w.updatedAt = Date()
        w.startedAt = nil
        w.finishedAt = nil
        let gen = generator
        for e in w.exercises.indices {
            guard let ex = w.exercises[e].exercise else { continue }
            if ex.isCardio {
                let role: Cardio.Role = (e == 0 && w.exercises.count > 1) ? .warmup : (w.exercises.count > 1 ? .finisher : .session)
                w.exercises[e] = gen.makeCardioEntry(for: ex, role: role)
                continue
            }
            let reps = w.exercises[e].targetReps ?? w.exercises[e].sets.first?.reps ?? settings.goal.targetReps
            let weight = gen.suggestedWeight(for: ex, reps: reps)
            w.exercises[e].suggestedWeight = weight
            for s in w.exercises[e].sets.indices {
                w.exercises[e].sets[s].id = UUID()
                w.exercises[e].sets[s].weight = weight
                w.exercises[e].sets[s].done = false
            }
            w.exercises[e].id = UUID()
        }
        current = w
        selectedTab = .workout
    }

    func startProgramDay(_ index: Int) {
        let schedule = settings.schedule
        guard schedule.indices.contains(index) else { return }
        current = generator.generate(focus: schedule[index], recovery: recovery, programDay: index)
    }

    func generateWorkout(focus: SplitFocus) {
        current = generator.generate(focus: focus, recovery: recovery)
    }

    func setActiveProfile(_ id: UUID) { settings.activeProfileID = id }

    func update(_ workout: Workout) {
        var w = workout
        w.updatedAt = Date()
        if w.startedAt == nil, w.completedSetCount > 0 { w.startedAt = Date() }
        current = w
    }

    func swap(itemID: UUID) {
        guard var w = current, let i = w.exercises.firstIndex(where: { $0.id == itemID }) else { return }
        let used = Set(w.exercises.map(\.exerciseID))
        guard let alt = generator.alternatives(to: w.exercises[i].exerciseID, excluding: used).randomElement() else { return }
        w.exercises[i] = generator.makeEntry(for: alt)
        update(w)
    }

    func replace(itemID: UUID, with exercise: Exercise) {
        guard var w = current, let i = w.exercises.firstIndex(where: { $0.id == itemID }) else { return }
        w.exercises[i] = generator.makeEntry(for: exercise)
        update(w)
    }

    func addExercise(_ exercise: Exercise) {
        guard var w = current else { return }
        w.exercises.append(generator.makeEntry(for: exercise))
        update(w)
    }

    func remove(itemID: UUID) {
        guard var w = current else { return }
        w.exercises.removeAll { $0.id == itemID }
        update(w)
    }

    func excludeExercise(_ id: String) { settings.excludedExerciseIDs.insert(id) }

    func discardCurrent() { current = nil }

    func finishCurrent() async {
        guard var w = current else { return }
        let end = Date()
        w.finishedAt = end
        if w.startedAt == nil { w.startedAt = end.addingTimeInterval(-45 * 60) }
        w.updatedAt = end
        current = nil
        history.append(w)
        advanceProgram(after: w)

        if settings.healthEnabled, !w.savedToHealth, let start = w.startedAt {
            var known = latestWeightKg
            if known == nil { known = await health.latestBodyMassKg() }
            let kg = known ?? 75
            let result = await saveToHealth(w, start: start, end: end, bodyKg: kg)
            if let i = history.firstIndex(where: { $0.id == w.id }) {
                history[i].savedToHealth = result.saved
                history[i].calories = result.kcal
                history[i].calorieSource = result.source
                history[i].averageHeartRate = result.heartRate?.average
                history[i].maxHeartRate = result.heartRate?.max
            }
        }
    }

    private struct HealthSaveResult {
        var saved = false
        var kcal: Double?
        var source: String?
        var heartRate: (average: Double, max: Double)?
    }

    /// Saves cardio blocks as walking/running/elliptical workouts and the rest as strength training,
    /// without overlapping so calories aren't counted twice. Strength calories come from the Watch's own
    /// sensors when it recorded them, else from heart rate, else a time-based estimate.
    private func saveToHealth(_ w: Workout, start: Date, end: Date, bodyKg: Double) async -> HealthSaveResult {
        var result = HealthSaveResult()
        result.heartRate = await health.heartRate(start: start, end: end)
        var strengthStart = start
        var strengthEnd = end
        var total = 0.0
        let cardio = w.exercises.enumerated().filter { $0.element.isCardio && $0.element.cardioMinutes > 0 }
        let strengthCount = w.exercises.filter { !$0.isCardio && $0.completedSets > 0 }.count
        for (index, item) in cardio {
            guard let s = item.sets.first(where: \.done) else { continue }
            let minutes = s.minutes ?? 0
            let seconds = minutes * 60
            let isWarmup = index == 0 && strengthCount > 0
            let blockStart: Date
            let blockEnd: Date
            if isWarmup {
                blockStart = strengthStart
                blockEnd = strengthStart.addingTimeInterval(seconds)
                strengthStart = blockEnd
            } else {
                blockEnd = strengthEnd
                blockStart = strengthEnd.addingTimeInterval(-seconds)
                strengthEnd = blockStart
            }
            let kcal = Cardio.calories(item.exerciseID, minutes: minutes, speed: s.speed, incline: s.incline,
                                       bodyKg: bodyKg, useKm: settings.useKilograms)
            var meters: Double?
            if let d = s.distance ?? Cardio.distance(item.exerciseID, minutes: minutes, speed: s.speed) {
                meters = d * (settings.useKilograms ? 1000 : 1609.34)
            }
            if await health.saveCardioWorkout(exerciseID: item.exerciseID, start: blockStart, end: blockEnd, kcal: kcal, distanceMeters: meters) {
                total += kcal
                result.saved = true
                result.source = "estimate"
            }
        }
        if strengthCount > 0, strengthEnd > strengthStart {
            let minutes = strengthEnd.timeIntervalSince(strengthStart) / 60
            let kcal: Double
            var record: Double?
            let source: String
            if let measured = await health.measuredActiveEnergy(start: strengthStart, end: strengthEnd), measured >= minutes * 0.5 {
                // The Watch already logged this energy to Apple Health; use it and don't add a duplicate.
                kcal = measured
                source = "watch"
            } else if let hr = await health.heartRate(start: strengthStart, end: strengthEnd), hr.average > 60 {
                let age = health.ageYears ?? 30
                let female = (health.healthSex ?? settings.sex) == .female
                kcal = HealthManager.heartRateCalories(averageBPM: hr.average, minutes: minutes, kg: bodyKg, age: age, female: female)
                record = kcal
                source = "heartRate"
            } else {
                kcal = HealthManager.estimatedCalories(start: strengthStart, end: strengthEnd, bodyMassKg: bodyKg)
                record = kcal
                source = "estimate"
            }
            if await health.saveStrengthWorkout(start: strengthStart, end: strengthEnd, kcal: record) {
                total += kcal
                result.saved = true
                result.source = source
            }
        }
        if result.saved { result.kcal = total }
        return result
    }

    /// Connects Apple Health. Returns nil when it worked, else the reason it didn't.
    func connectHealth() async -> String? {
        let ok = await health.requestAuthorization()
        settings.healthEnabled = ok
        return ok ? nil : (health.lastError ?? "Apple Health didn't respond.")
    }

    private func advanceProgram(after w: Workout) {
        guard let day = w.programDay else { return }
        settings.programDay = day + 1
    }

    func deleteWorkout(id: UUID) { history.removeAll { $0.id == id } }

    private func receiveFromWatch(_ w: Workout, finished: Bool) {
        if finished {
            if let i = history.firstIndex(where: { $0.id == w.id }) {
                history[i] = w
            } else {
                history.append(w)
                advanceProgram(after: w)
            }
            if current?.id == w.id { current = nil }
        } else if let c = current, c.id == w.id, w.updatedAt > c.updatedAt {
            current = w
        }
    }

    // MARK: Body weight

    func logWeight(displayValue: Double, date: Date = Date()) {
        let kg = settings.kg(fromDisplay: displayValue)
        guard kg > 20, kg < 400 else { return }
        weighIns.append(WeighIn(date: date, kg: kg))
        weighIns.sort { $0.date < $1.date }
        if settings.healthEnabled {
            Task { await health.saveBodyMass(kg: kg, date: date) }
        }
    }

    func deleteWeighIn(id: UUID) { weighIns.removeAll { $0.id == id } }

    // MARK: Strength

    func bestSet(for exerciseID: String) -> LoggedSet? {
        history.flatMap { $0.exercises }
            .filter { $0.exerciseID == exerciseID }
            .flatMap(\.sets)
            .filter { $0.done && $0.weight > 0 }
            .max { WorkoutGenerator.oneRepMax($0) < WorkoutGenerator.oneRepMax($1) }
    }

    /// Best estimated 1RM so far (from your lifts), else the starting estimate.
    func currentOneRepMax(_ exerciseID: String) -> Double? {
        if let s = bestSet(for: exerciseID) { return WorkoutGenerator.oneRepMax(s) }
        guard let ex = ExerciseLibrary.byID[exerciseID] else { return nil }
        return generator.predictedOneRepMax(ex)
    }

    /// (date, best estimated 1RM that day) for charts.
    func oneRepMaxHistory(_ exerciseID: String) -> [(Date, Double)] {
        history.compactMap { w in
            let best = w.exercises.filter { $0.exerciseID == exerciseID }
                .flatMap(\.sets).filter { $0.done && $0.weight > 0 }
                .map(WorkoutGenerator.oneRepMax).max()
            return best.map { (w.finishedAt ?? w.createdAt, $0) }
        }
    }

    func addStrengthTarget(exerciseID: String, target: Double) {
        let start = currentOneRepMax(exerciseID) ?? 0
        settings.strengthTargets.removeAll { $0.exerciseID == exerciseID }
        settings.strengthTargets.append(StrengthTarget(exerciseID: exerciseID, target: target, start: start))
    }

    func workouts(inWeekOf date: Date = Date()) -> [Workout] {
        let cal = Calendar.current
        guard let week = cal.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return history.filter { week.contains($0.finishedAt ?? $0.createdAt) }
    }
}

enum AppTab: Hashable {
    case workout, program, progress, recovery, settings
}
