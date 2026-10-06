import Foundation

/// A bodyweight skill progression, easiest first. You level up by moving to the next exercise
/// instead of adding weight.
struct SkillLadder: Identifiable, Sendable {
    let id: String
    let name: String
    let rungs: [String]
}

enum Calisthenics {
    static let ladders: [SkillLadder] = [
        SkillLadder(id: "push", name: "Push-up", rungs: ["knee_pushup", "incline_pushup", "pushup", "diamond_pushup", "archer_pushup"]),
        SkillLadder(id: "pull", name: "Pull-up", rungs: ["inverted_row", "negative_pullup", "pullup"]),
        SkillLadder(id: "dip", name: "Dip", rungs: ["bench_dip", "dips"]),
        SkillLadder(id: "core", name: "Core to L-sit", rungs: ["plank", "hollow_hold", "hanging_knee_raise", "hanging_leg_raise", "l_sit"]),
        SkillLadder(id: "legs", name: "Squat to pistol", rungs: ["bw_squat", "bw_lunge", "bw_split_squat", "pistol_squat"]),
    ]

    /// Level up after every planned set reaches this many reps (or seconds for holds).
    static let repGoal = 12
    static let holdGoal = 45

    static func ladder(containing id: String) -> SkillLadder? {
        ladders.first { $0.rungs.contains(id) }
    }

    static func goal(for id: String) -> Int {
        (ExerciseLibrary.byID[id]?.isTimed ?? false) ? holdGoal : repGoal
    }

    /// "3 × 12" or "3 × 45 s"
    static func goalText(for id: String) -> String {
        (ExerciseLibrary.byID[id]?.isTimed ?? false) ? "3 × \(holdGoal) s" : "3 × \(repGoal)"
    }

    /// Done sets from the most recent finished session of this exercise.
    static func lastSession(_ id: String, history: [Workout]) -> WorkoutExercise? {
        for w in history.reversed() where w.finishedAt != nil {
            if let item = w.exercises.first(where: { $0.exerciseID == id }), item.sets.contains(where: \.done) {
                return item
            }
        }
        return nil
    }

    /// The last session hit the level-up goal on every planned set (at least 3).
    static func passed(_ id: String, history: [Workout]) -> Bool {
        guard let item = lastSession(id, history: history) else { return false }
        let done = item.sets.filter(\.done)
        return done.count >= max(3, item.sets.count) && done.allSatisfy { $0.reps >= goal(for: id) }
    }

    /// The exercise to train now on this ladder: the hardest one you've trained, or the next one up
    /// once you've passed it. Skips exercises you can't do with your equipment or have ruled out.
    static func currentRung(_ ladder: SkillLadder, history: [Workout], available: Set<String>) -> String? {
        let rungs = ladder.rungs.filter { available.contains($0) }
        guard !rungs.isEmpty else { return nil }
        let trained = Set(history.filter { $0.finishedAt != nil }.flatMap { $0.exercises.filter { $0.sets.contains(where: \.done) }.map(\.exerciseID) })
        guard let top = rungs.lastIndex(where: { trained.contains($0) }) else { return rungs[0] }
        if passed(rungs[top], history: history), top + 1 < rungs.count { return rungs[top + 1] }
        return rungs[top]
    }

    /// Reps to aim for: one more than your best last time, up to the level-up goal.
    static func targetReps(_ id: String, history: [Workout], start: Int = 8) -> Int {
        guard let item = lastSession(id, history: history) else { return start }
        let best = item.sets.filter(\.done).map(\.reps).max() ?? start
        let allDone = item.sets.allSatisfy(\.done)
        return min(repGoal, max(3, allDone ? best + 1 : best))
    }
}
