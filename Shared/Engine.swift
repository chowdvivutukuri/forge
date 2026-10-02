import Foundation

/// Rough intermediate one-rep-max standards as a multiple of body weight (men).
/// Dumbbell and kettlebell values are per hand (or for the single weight when held with both hands).
enum StrengthStandards {
    static let ratios: [String: Double] = [
        // Barbell
        "back_squat": 1.25, "front_squat": 1.0, "deadlift": 1.5, "bb_bench": 1.0, "bb_incline": 0.85, "bb_ohp": 0.65,
        "bb_row": 0.8, "bb_rdl": 1.1, "hip_thrust": 1.4, "close_grip_bench": 0.85, "skullcrusher": 0.4, "bb_curl": 0.45,
        "bb_shrug": 1.1, "smith_bench": 0.95, "smith_squat": 1.2,
        // Dumbbell
        "db_bench": 0.38, "db_incline": 0.33, "db_ohp": 0.28, "db_row": 0.4, "db_curl": 0.18, "hammer_curl": 0.2,
        "db_lateral": 0.1, "db_rear_fly": 0.09, "db_fly": 0.18, "db_floor_press": 0.35, "db_oh_ext": 0.3,
        "goblet_squat": 0.45, "split_squat": 0.25, "db_lunge": 0.25, "db_rdl": 0.4, "db_shrug": 0.45, "db_calf": 0.4,
        // Kettlebell
        "kb_swing": 0.4, "kb_goblet": 0.45, "kb_press": 0.25, "kb_row": 0.35, "kb_curl": 0.15, "kb_windmill": 0.15,
        // Machines and cables (stack weight)
        "leg_press": 2.2, "hack_squat": 1.4, "leg_ext": 0.75, "leg_curl": 0.55, "seated_leg_curl": 0.6,
        "machine_chest": 0.85, "pec_deck": 0.6, "reverse_fly_machine": 0.4, "machine_shoulder": 0.6,
        "lat_pulldown": 0.8, "cable_row": 0.8, "machine_row": 0.8, "preacher_curl": 0.35, "abductor_machine": 0.8,
        "adductor_machine": 0.8, "calf_machine": 1.2, "ab_crunch_machine": 0.5, "pushdown": 0.35, "cable_curl": 0.3,
        "face_pull": 0.3, "cable_fly": 0.2, "cable_lateral": 0.07, "cable_crunch": 0.6, "pallof": 0.2,
    ]
}

enum RecoveryEngine {
    /// Roughly ten hard sets fully fatigues a muscle.
    static let capacity = 10.0

    /// 1.0 = fully recovered, 0.0 = heavily fatigued.
    static func recovery(history: [Workout], now: Date = Date()) -> [Muscle: Double] {
        var fatigue: [Muscle: Double] = [:]
        for workout in history {
            let end = workout.finishedAt ?? workout.createdAt
            let hours = now.timeIntervalSince(end) / 3600
            guard hours >= 0, hours < 120 else { continue }
            for item in workout.exercises {
                guard let ex = item.exercise else { continue }
                let sets = Double(item.completedSets)
                guard sets > 0 else { continue }
                for m in ex.primary { fatigue[m, default: 0] += sets * remaining(hours, m) }
                for m in ex.secondary { fatigue[m, default: 0] += sets * 0.5 * remaining(hours, m) }
            }
        }
        var result: [Muscle: Double] = [:]
        for m in Muscle.allCases {
            result[m] = max(0, min(1, 1 - (fatigue[m] ?? 0) / capacity))
        }
        return result
    }

    private static func remaining(_ hours: Double, _ m: Muscle) -> Double {
        max(0, 1 - hours / m.recoveryHours)
    }
}

struct WorkoutGenerator {
    var settings: UserSettings
    var history: [Workout]
    var bodyWeightKg: Double?
    var now: Date = Date()
    /// Random spread added to exercise scores; 0 gives a repeatable preview.
    var jitter: Double = 2.5

    var availableExercises: [Exercise] {
        ExerciseLibrary.available(with: settings.availableEquipment, excluding: settings.excludedExerciseIDs)
    }

    // MARK: Workouts

    func generateNext() -> Workout {
        let recovery = RecoveryEngine.recovery(history: history, now: now)
        let day = settings.programDay % max(1, settings.schedule.count)
        return generate(focus: settings.nextFocus, recovery: recovery, programDay: day)
    }

    func generate(focus: SplitFocus, recovery: [Muscle: Double], programDay: Int? = nil) -> Workout {
        let targets = Set(focus.muscles)
        var muscleWeight: [Muscle: Double] = [:]
        for m in targets { muscleWeight[m] = recovery[m] ?? 1 }
        let recentIDs = Set(history.suffix(2).flatMap { $0.exercises.map(\.exerciseID) })

        var pool = availableExercises.filter { !Set($0.primary).isDisjoint(with: targets) }
        var chosen: [Exercise] = []
        let count = max(3, min(10, settings.exercisesPerWorkout))

        while chosen.count < count, !pool.isEmpty {
            var best: Exercise?
            var bestScore = -Double.infinity
            for ex in pool {
                let primary = ex.primary.map { muscleWeight[$0] ?? 0 }.reduce(0, +) / Double(ex.primary.count)
                var score = primary * 10
                if ex.isCompound { score += chosen.count < 2 ? 4 : 1 }
                if recentIDs.contains(ex.id) { score -= 2 }
                if jitter > 0 { score += Double.random(in: 0...jitter) }
                if score > bestScore { bestScore = score; best = ex }
            }
            guard let pick = best else { break }
            chosen.append(pick)
            pool.removeAll { $0.id == pick.id }
            for m in pick.primary { muscleWeight[m] = (muscleWeight[m] ?? 0) * 0.35 }
            for m in pick.secondary { muscleWeight[m] = (muscleWeight[m] ?? 0) * 0.75 }
        }

        let ordered = chosen.filter(\.isCompound) + chosen.filter { !$0.isCompound }
        var title = focus.displayName
        if let d = programDay { title = "Day \(d + 1) · \(focus.displayName)" }
        return Workout(title: title, exercises: ordered.map { makeEntry(for: $0) },
                       equipmentProfileName: settings.activeProfile.name, programDay: programDay)
    }

    /// Each day of the program, generated without randomness so the preview is stable.
    func programPreview() -> [Workout] {
        var gen = self
        gen.jitter = 0
        var simulated = history
        var out: [Workout] = []
        let schedule = settings.schedule
        let gap = 7.0 / Double(max(1, schedule.count))
        for (i, focus) in schedule.enumerated() {
            gen.history = simulated
            gen.now = now.addingTimeInterval(Double(i) * gap * 86_400)
            var w = gen.generate(focus: focus, recovery: RecoveryEngine.recovery(history: simulated, now: gen.now), programDay: i)
            w.createdAt = gen.now
            out.append(w)
            var done = w
            done.finishedAt = gen.now.addingTimeInterval(3600)
            for e in done.exercises.indices {
                for s in done.exercises[e].sets.indices { done.exercises[e].sets[s].done = true }
            }
            simulated.append(done)
        }
        return out
    }

    func makeEntry(for ex: Exercise) -> WorkoutExercise {
        let goal = settings.goal
        let reps = ex.isCompound ? goal.targetReps : max(goal.targetReps, 10)
        let setCount = ex.isCompound ? goal.sets : 3
        let weight = suggestedWeight(for: ex, reps: reps)
        let sets = (0..<setCount).map { _ in LoggedSet(reps: reps, weight: weight) }
        return WorkoutExercise(exerciseID: ex.id, sets: sets, restSeconds: ex.isCompound ? goal.restSeconds : min(goal.restSeconds, 75),
                               suggestedWeight: weight, targetReps: reps)
    }

    // MARK: Weights

    static func oneRepMax(_ s: LoggedSet) -> Double { s.weight * (1 + Double(s.reps) / 30) }

    func step(for ex: Exercise) -> Double {
        let kg = settings.useKilograms
        if ex.equipment.contains(.dumbbell) { return kg ? 2 : 5 }
        if ex.equipment.contains(.kettlebell) { return kg ? 4 : 5 }
        return kg ? 2.5 : 5
    }

    func minimumWeight(for ex: Exercise) -> Double {
        let kg = settings.useKilograms
        if ex.equipment.contains(.barbell) { return kg ? 20 : 45 }
        if ex.equipment.contains(.smith) { return kg ? 10 : 20 }
        if ex.equipment.contains(.kettlebell) { return kg ? 4 : 10 }
        return step(for: ex)
    }

    func round(_ w: Double, for ex: Exercise) -> Double {
        let st = step(for: ex)
        return max(minimumWeight(for: ex), (w / st).rounded() * st)
    }

    /// Best set from the most recent finished session of this exercise.
    func lastPerformance(_ id: String) -> WorkoutExercise? {
        for workout in history.reversed() where workout.finishedAt != nil {
            if let item = workout.exercises.first(where: { $0.exerciseID == id }),
               item.sets.contains(where: { $0.done && $0.weight > 0 && $0.reps > 0 }) {
                return item
            }
        }
        return nil
    }

    /// Estimated 1RM from body weight, level and sex, in the user's unit. Nil when there's no standard.
    func predictedOneRepMax(_ ex: Exercise) -> Double? {
        guard !ex.isBodyweight else { return nil }
        let ratio = StrengthStandards.ratios[ex.id] ?? defaultRatio(ex)
        let bw = bodyWeightKg ?? 75
        let kg = ratio * bw * settings.experience.strengthFactor * settings.sex.strengthFactor(lowerBody: ex.isLowerBody)
        return settings.useKilograms ? kg : kg * 2.20462
    }

    private func defaultRatio(_ ex: Exercise) -> Double {
        if ex.equipment.contains(.barbell) { return ex.isCompound ? 0.8 : 0.4 }
        if ex.equipment.contains(.dumbbell) { return ex.isCompound ? 0.3 : 0.12 }
        if ex.equipment.contains(.kettlebell) { return 0.25 }
        return ex.isCompound ? 0.6 : 0.3
    }

    /// How the user's real lifts compare with the standards (1.0 = as predicted).
    /// Used to scale suggestions for exercises they haven't done yet.
    var calibration: Double {
        var ratios: [Double] = []
        var seen = Set<String>()
        let cutoff = now.addingTimeInterval(-60 * 86_400)
        for workout in history.reversed() where (workout.finishedAt ?? .distantPast) > cutoff {
            for item in workout.exercises where !seen.contains(item.exerciseID) {
                guard let ex = item.exercise, let predicted = predictedOneRepMax(ex), predicted > 0 else { continue }
                let best = item.sets.filter { $0.done && $0.weight > 0 }.map(Self.oneRepMax).max()
                guard let best else { continue }
                seen.insert(item.exerciseID)
                ratios.append(best / predicted)
            }
        }
        guard !ratios.isEmpty else { return 1 }
        let sorted = ratios.sorted()
        let median = sorted.count % 2 == 1 ? sorted[sorted.count / 2] : (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
        return max(0.4, min(2.0, median))
    }

    /// Next working weight. Uses your last session when there is one (double progression),
    /// otherwise a starting estimate from your profile, scaled to how you've actually been lifting.
    func suggestedWeight(for ex: Exercise, reps: Int) -> Double {
        if ex.isBodyweight { return 0 }
        if let last = lastPerformance(ex.id) {
            let done = last.sets.filter { $0.done && $0.weight > 0 }
            let top = done.map(\.weight).max() ?? 0
            let lastTarget = last.targetReps ?? reps
            if abs(lastTarget - reps) > 2, let best = done.map(Self.oneRepMax).max() {
                return round(best / (1 + Double(reps) / 30) * 0.95, for: ex)
            }
            let atTop = done.filter { $0.weight >= top }
            let allDone = last.sets.allSatisfy(\.done)
            let hitReps = !atTop.isEmpty && atTop.allSatisfy { $0.reps >= lastTarget }
            let avgReps = Double(done.map(\.reps).reduce(0, +)) / Double(max(1, done.count))
            if allDone && hitReps {
                let inc = (ex.isCompound && ex.isLowerBody) ? step(for: ex) * 2 : step(for: ex)
                return round(max(top + inc, top * 1.025), for: ex)
            }
            if avgReps < Double(lastTarget) - 2 {
                return round(top * 0.93, for: ex)
            }
            return round(top, for: ex)
        }
        guard let oneRM = predictedOneRepMax(ex) else { return minimumWeight(for: ex) }
        let working = oneRM * calibration / (1 + Double(reps) / 30) * 0.9
        return round(working, for: ex)
    }

    /// Swaps that hit at least one of the same primary muscles with available equipment.
    func alternatives(to exerciseID: String, excluding used: Set<String>) -> [Exercise] {
        guard let ex = ExerciseLibrary.byID[exerciseID] else { return [] }
        let primary = Set(ex.primary)
        return availableExercises.filter {
            $0.id != ex.id && !used.contains($0.id) && !primary.isDisjoint(with: $0.primary)
        }
    }
}

// MARK: - iPhone <-> Watch sync

enum SyncKey {
    static let workout = "workout"     // Data (JSON Workout); empty Data = no current workout
    static let finished = "finished"   // Data (JSON Workout) finished on the watch
    static let useKg = "useKg"         // Bool
    static let sentAt = "sentAt"       // Double, forces context changes to deliver
}

enum SyncCoding {
    static func encode<T: Encodable>(_ value: T) -> Data? { try? JSONEncoder().encode(value) }
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? { try? JSONDecoder().decode(type, from: data) }
}
