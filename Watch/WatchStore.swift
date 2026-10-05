import Foundation
import WatchConnectivity

@MainActor
final class WatchStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published var workout: Workout? { didSet { persist() } }
    @Published var useKilograms = false
    @Published var abhiMode = ForgeColors.abhiMode

    private let workoutKey = "forge.watch.workout"
    private let kgKey = "forge.watch.kg"
    private let customKey = "forge.watch.custom"

    override init() {
        super.init()
        if let d = UserDefaults.standard.data(forKey: workoutKey) {
            workout = SyncCoding.decode(Workout.self, from: d)
        }
        useKilograms = UserDefaults.standard.bool(forKey: kgKey)
        if let d = UserDefaults.standard.data(forKey: customKey), let list = SyncCoding.decode([Exercise].self, from: d) {
            ExerciseLibrary.custom = list
        }
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    var unit: String { useKilograms ? "kg" : "lb" }
    var unitSettings: UserSettings {
        var s = UserSettings()
        s.useKilograms = useKilograms
        return s
    }
    var weightStep: Double { useKilograms ? 2.5 : 5 }

    private func persist() {
        if let w = workout, let d = SyncCoding.encode(w) {
            UserDefaults.standard.set(d, forKey: workoutKey)
        } else {
            UserDefaults.standard.removeObject(forKey: workoutKey)
        }
    }

    // MARK: Logging

    func logSet(itemID: UUID, setID: UUID, reps: Int, weight: Double) {
        guard var w = workout,
              let i = w.exercises.firstIndex(where: { $0.id == itemID }),
              let j = w.exercises[i].sets.firstIndex(where: { $0.id == setID }) else { return }
        w.exercises[i].sets[j].reps = reps
        w.exercises[i].sets[j].weight = weight
        w.exercises[i].sets[j].done = true
        commit(&w)
    }

    func logCardio(itemID: UUID, minutes: Double) {
        guard var w = workout, let i = w.exercises.firstIndex(where: { $0.id == itemID }) else { return }
        if w.exercises[i].sets.isEmpty { w.exercises[i].sets.append(LoggedSet(reps: 0, weight: 0)) }
        w.exercises[i].sets[0].minutes = minutes
        w.exercises[i].sets[0].done = true
        let s = w.exercises[i].sets[0]
        w.exercises[i].sets[0].distance = Cardio.distance(w.exercises[i].exerciseID, minutes: minutes, speed: s.speed)
        commit(&w)
    }

    func addSet(itemID: UUID) {
        guard var w = workout, let i = w.exercises.firstIndex(where: { $0.id == itemID }) else { return }
        let last = w.exercises[i].sets.last ?? LoggedSet(reps: 10, weight: 0)
        w.exercises[i].sets.append(LoggedSet(reps: last.reps, weight: last.weight))
        commit(&w)
    }

    func undoLastSet(itemID: UUID) {
        guard var w = workout, let i = w.exercises.firstIndex(where: { $0.id == itemID }),
              let j = w.exercises[i].sets.lastIndex(where: \.done) else { return }
        w.exercises[i].sets[j].done = false
        commit(&w)
    }

    private func commit(_ w: inout Workout) {
        if w.startedAt == nil { w.startedAt = Date() }
        w.updatedAt = Date()
        workout = w
        send(w)
    }

    func finish(calories: Double?, averageHeartRate: Double?, maxHeartRate: Double?, savedToHealth: Bool) {
        guard var w = workout else { return }
        let now = Date()
        w.finishedAt = now
        if w.startedAt == nil { w.startedAt = now.addingTimeInterval(-45 * 60) }
        w.calories = calories
        w.averageHeartRate = averageHeartRate
        w.maxHeartRate = maxHeartRate
        w.calorieSource = calories == nil ? nil : "watch"
        w.savedToHealth = savedToHealth
        w.updatedAt = now
        if let d = SyncCoding.encode(w) {
            // Queued and delivered even if the iPhone isn't reachable right now.
            WCSession.default.transferUserInfo([SyncKey.finished: d])
        }
        workout = nil
    }

    private func send(_ w: Workout) {
        let s = WCSession.default
        guard s.activationState == .activated, let d = SyncCoding.encode(w) else { return }
        // Latest-wins context: delivered as soon as the phone can receive it.
        try? s.updateApplicationContext([SyncKey.workout: d, SyncKey.sentAt: Date().timeIntervalSince1970])
        if s.isReachable {
            s.sendMessage([SyncKey.workout: d], replyHandler: nil, errorHandler: nil)
        }
    }

    // MARK: Receiving from iPhone

    private struct Received: Sendable {
        var hasWorkoutKey = false
        var workoutData: Data?
        var useKg: Bool?
        var abhi: Bool?
        var custom: Data?
    }

    nonisolated private static func extract(_ payload: [String: Any]) -> Received {
        var r = Received()
        if let d = payload[SyncKey.workout] as? Data {
            r.hasWorkoutKey = true
            r.workoutData = d
        }
        r.useKg = payload[SyncKey.useKg] as? Bool
        r.abhi = payload[SyncKey.abhi] as? Bool
        r.custom = payload[SyncKey.custom] as? Data
        return r
    }

    private func apply(_ r: Received) {
        if let purple = r.abhi, purple != abhiMode {
            ForgeColors.setAbhiMode(purple)
            abhiMode = purple
        }
        if let d = r.custom, let list = SyncCoding.decode([Exercise].self, from: d) {
            ExerciseLibrary.custom = list
            UserDefaults.standard.set(d, forKey: customKey)
            objectWillChange.send()
        }
        if let kg = r.useKg {
            useKilograms = kg
            UserDefaults.standard.set(kg, forKey: kgKey)
        }
        guard r.hasWorkoutKey, let data = r.workoutData else { return }
        if data.isEmpty {
            workout = nil  // finished or discarded on the iPhone
            return
        }
        guard let incoming = SyncCoding.decode(Workout.self, from: data) else { return }
        if let local = workout, local.id == incoming.id, local.updatedAt >= incoming.updatedAt { return }
        workout = incoming
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let r = Self.extract(session.receivedApplicationContext)
        Task { @MainActor in self.apply(r) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let r = Self.extract(applicationContext)
        Task { @MainActor in self.apply(r) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let r = Self.extract(message)
        Task { @MainActor in self.apply(r) }
    }
}
