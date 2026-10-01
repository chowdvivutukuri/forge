import Foundation
import SwiftUI

@MainActor
final class WorkoutStore: ObservableObject {
    @Published var settings: UserSettings { didSet { stateChanged(pushToWatch: true) } }
    @Published private(set) var history: [Workout] { didSet { stateChanged(pushToWatch: false) } }
    @Published var current: Workout? { didSet { stateChanged(pushToWatch: true) } }
    @Published var plan: [Workout] { didSet { stateChanged(pushToWatch: false) } }

    let health = HealthManager()
    let connectivity = PhoneConnectivity()
    let backup = CloudBackup()

    struct Saved: Codable {
        var settings: UserSettings
        var history: [Workout]
        var current: Workout?
        var plan: [Workout]?
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
            plan = saved.plan ?? []
        } else {
            settings = UserSettings()
            history = []
            current = nil
            plan = []
        }
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
        let saved = Saved(settings: settings, history: history, current: current, plan: plan, savedAt: Date())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(saved)
    }

    private func stateChanged(pushToWatch: Bool) {
        let saved = Saved(settings: settings, history: history, current: current, plan: plan, savedAt: Date())
        if let data = try? JSONEncoder().encode(saved) {
            try? data.write(to: fileURL, options: .atomic)
        }
        if let data = snapshot() { backup.scheduleBackup(data) }
        if pushToWatch { connectivity.push(current: current, settings: settings) }
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
        plan = saved.plan ?? []
        return true
    }

    func eraseAll() {
        history = []
        current = nil
        plan = []
        settings = UserSettings()
    }

    // MARK: Derived

    var recovery: [Muscle: Double] { RecoveryEngine.recovery(history: history) }
    var generator: WorkoutGenerator { WorkoutGenerator(settings: settings, history: history) }
    var suggestedFocus: SplitFocus { generator.pickFocus(recovery: recovery) }

    // MARK: Workout actions

    func generateWorkout() { current = generator.generate() }

    func generateWorkout(focus: SplitFocus) {
        current = generator.generate(focus: focus, recovery: recovery)
    }

    func makePlan(sessions: Int) { plan = generator.planWeek(sessions: sessions) }

    func startPlanned(_ id: UUID) {
        guard let i = plan.firstIndex(where: { $0.id == id }) else { return }
        var w = plan.remove(at: i)
        w.createdAt = Date()
        w.updatedAt = Date()
        // Refresh weights using the latest history.
        let gen = generator
        for e in w.exercises.indices {
            guard let ex = w.exercises[e].exercise else { continue }
            let reps = w.exercises[e].sets.first?.reps ?? settings.goal.targetReps
            let weight = gen.suggestedWeight(for: ex, reps: reps)
            for s in w.exercises[e].sets.indices { w.exercises[e].sets[s].weight = weight }
        }
        current = w
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

        if settings.healthEnabled, !w.savedToHealth, let start = w.startedAt {
            let kg = await health.latestBodyMassKg() ?? 75
            let saved = await health.saveStrengthWorkout(start: start, end: end, bodyMassKg: kg)
            if saved, let i = history.firstIndex(where: { $0.id == w.id }) {
                history[i].savedToHealth = true
                history[i].calories = HealthManager.estimatedCalories(start: start, end: end, bodyMassKg: kg)
            }
        }
    }

    func deleteWorkout(id: UUID) { history.removeAll { $0.id == id } }

    private func receiveFromWatch(_ w: Workout, finished: Bool) {
        if finished {
            if let i = history.firstIndex(where: { $0.id == w.id }) { history[i] = w } else { history.append(w) }
            if current?.id == w.id { current = nil }
        } else if let c = current, c.id == w.id, w.updatedAt > c.updatedAt {
            current = w
        }
    }

    // MARK: History helpers

    func bestSet(for exerciseID: String) -> LoggedSet? {
        history.flatMap { $0.exercises }
            .filter { $0.exerciseID == exerciseID }
            .flatMap(\.sets)
            .filter { $0.done && $0.weight > 0 }
            .max { WorkoutGenerator.oneRepMax($0) < WorkoutGenerator.oneRepMax($1) }
    }
}
