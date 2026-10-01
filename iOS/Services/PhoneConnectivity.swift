import Foundation
import WatchConnectivity

/// Sends the current workout to the Watch and receives logged sets back.
@MainActor
final class PhoneConnectivity: NSObject, WCSessionDelegate {
    var onWorkoutUpdate: ((Workout) -> Void)?
    var onWorkoutFinished: ((Workout) -> Void)?
    var onActivated: (() -> Void)?

    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    func activate() {
        guard let s = session else { return }
        s.delegate = self
        s.activate()
    }

    func push(current: Workout?, settings: UserSettings) {
        guard let s = session, s.activationState == .activated, s.isPaired, s.isWatchAppInstalled else { return }
        let workoutData: Data = current.flatMap { SyncCoding.encode($0) } ?? Data()
        let context: [String: Any] = [
            SyncKey.workout: workoutData,
            SyncKey.useKg: settings.useKilograms,
            SyncKey.sentAt: Date().timeIntervalSince1970,
        ]
        try? s.updateApplicationContext(context)
    }

    // MARK: WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let received = Self.extract(session.receivedApplicationContext)
        Task { @MainActor in
            self.deliver(received)
            self.onActivated?()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let received = Self.extract(applicationContext)
        Task { @MainActor in self.deliver(received) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let received = Self.extract(message)
        Task { @MainActor in self.deliver(received) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        let received = Self.extract(userInfo)
        Task { @MainActor in self.deliver(received) }
    }

    private struct Received: Sendable {
        var update: Workout?
        var finished: Workout?
    }

    nonisolated private static func extract(_ payload: [String: Any]) -> Received {
        var r = Received()
        if let d = payload[SyncKey.workout] as? Data, !d.isEmpty { r.update = SyncCoding.decode(Workout.self, from: d) }
        if let d = payload[SyncKey.finished] as? Data { r.finished = SyncCoding.decode(Workout.self, from: d) }
        return r
    }

    private func deliver(_ r: Received) {
        if let w = r.update { onWorkoutUpdate?(w) }
        if let w = r.finished { onWorkoutFinished?(w) }
    }
}
