import ActivityKit
import Foundation

/// Shows the workout on the lock screen and Dynamic Island: current exercise, next set, rest countdown.
@MainActor
final class LiveActivityManager {
    private var activity: Activity<WorkoutActivityAttributes>?
    private var workoutID: UUID?
    private var lastState: WorkoutActivityAttributes.ContentState?

    var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func sync(_ workout: Workout?, restEnd: Date?, settings: UserSettings) {
        guard let w = workout, w.finishedAt == nil, w.completedSetCount > 0 else {
            end()
            return
        }
        let state = Self.state(for: w, restEnd: restEnd, settings: settings)
        if let activity, workoutID == w.id {
            guard state != lastState else { return }
            lastState = state
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
            return
        }
        end()
        guard isAvailable else { return }
        let attributes = WorkoutActivityAttributes(title: w.title, startedAt: w.startedAt ?? Date())
        activity = try? Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: nil))
        workoutID = w.id
        lastState = state
    }

    func end() {
        lastState = nil
        workoutID = nil
        // Also clears cards left over if the app was closed mid-workout.
        let all = Activity<WorkoutActivityAttributes>.activities
        activity = nil
        for a in all { Task { await a.end(nil, dismissalPolicy: .immediate) } }
    }

    private static func state(for w: Workout, restEnd: Date?, settings: UserSettings) -> WorkoutActivityAttributes.ContentState {
        let total = w.exercises.reduce(0) { $0 + $1.sets.count }
        let done = w.completedSetCount
        let abhi = settings.abhiMode
        guard let item = w.exercises.first(where: { !$0.sets.allSatisfy(\.done) }) else {
            return .init(exerciseName: "All sets done", setLabel: "Finish when ready", detail: "",
                         completedSets: done, totalSets: total, restEnd: nil, abhi: abhi)
        }
        if item.isCardio {
            return .init(exerciseName: item.name, setLabel: "Cardio", detail: item.targetMinutes.map { "\(Int($0)) min" } ?? "",
                         completedSets: done, totalSets: total, restEnd: restEnd, abhi: abhi)
        }
        let index = item.sets.firstIndex { !$0.done } ?? 0
        let set = item.sets[index]
        let weight = set.weight > 0 ? "\(set.weight.formatted(.number.precision(.fractionLength(0...1)))) \(settings.weightUnit) × " : ""
        return .init(exerciseName: item.name, setLabel: "Set \(index + 1) of \(item.sets.count)",
                     detail: "\(weight)\(set.reps)", completedSets: done, totalSets: total,
                     restEnd: restEnd.flatMap { $0 > Date() ? $0 : nil }, abhi: abhi)
    }
}
