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
        connectivity.onWorkoutUpdate = { [weak self] w in self?.receiveFromWatch(w, finished: false) }
        connectivity.onWorkoutFinished = { [weak self] w in self?.receiveFromWatch(w, finished: true) }
        connectivity.onActivated = { [weak self] in
            guard let self else { return }
            self.connectivity.push(current: self.current, settings: self.settings)
        }
        connectivity.activate()
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
    func startNextProgramDay() { current = generator.generateNext() }

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
            let total = await saveToHealth(w, start: start, end: end, bodyKg: kg)
            if let total, let i = history.firstIndex(where: { $0.id == w.id }) {
                history[i].savedToHealth = true
                history[i].calories = total
            }
        }
    }

    /// Saves cardio blocks as walking/running/elliptical workouts and the rest as strength training,
    /// without overlapping so calories aren't counted twice. Returns total kcal, or nil if nothing saved.
    private func saveToHealth(_ w: Workout, start: Date, end: Date, bodyKg: Double) async -> Double? {
        var strengthStart = start
        var strengthEnd = end
        var total = 0.0
        var savedAny = false
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
                savedAny = true
            }
        }
        if strengthCount > 0, strengthEnd > strengthStart {
            if await health.saveStrengthWorkout(start: strengthStart, end: strengthEnd, bodyMassKg: bodyKg) {
                total += HealthManager.estimatedCalories(start: strengthStart, end: strengthEnd, bodyMassKg: bodyKg)
                savedAny = true
            }
        }
        return savedAny ? total : nil
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
