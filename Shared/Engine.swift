import Foundation

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
    var now: Date = Date()

    var availableExercises: [Exercise] {
        ExerciseLibrary.available(with: settings.availableEquipment, excluding: settings.excludedExerciseIDs)
    }

    private func averageRecovery(_ focus: SplitFocus, _ recovery: [Muscle: Double]) -> Double {
        let ms = focus.muscles
        return ms.map { recovery[$0] ?? 1 }.reduce(0, +) / Double(ms.count)
    }

    /// How many available exercises train this split's muscles.
    private func coverage(_ focus: SplitFocus) -> Int {
        let targets = Set(focus.muscles)
        return availableExercises.filter { !Set($0.primary).isDisjoint(with: targets) }.count
    }

    func pickFocus(recovery: [Muscle: Double]) -> SplitFocus {
        if settings.focus != .auto { return settings.focus }
        if averageRecovery(.fullBody, recovery) >= 0.95 { return .fullBody }
        let candidates: [SplitFocus] = [.push, .pull, .legs, .upper, .lower]
            .filter { coverage($0) >= 3 }
        return candidates.max { averageRecovery($0, recovery) < averageRecovery($1, recovery) } ?? .fullBody
    }

    func generate() -> Workout {
        let recovery = RecoveryEngine.recovery(history: history, now: now)
        return generate(focus: pickFocus(recovery: recovery), recovery: recovery)
    }

    func generate(focus: SplitFocus, recovery: [Muscle: Double]) -> Workout {
        let targets = Set(focus.muscles)
        var muscleWeight: [Muscle: Double] = [:]
        for m in targets { muscleWeight[m] = recovery[m] ?? 1 }
        let recentIDs = Set(history.suffix(2).flatMap { $0.exercises.map(\.exerciseID) })

        var pool = availableExercises.filter { !Set($0.primary).isDisjoint(with: targets) }
        var chosen: [Exercise] = []
        let count = max(3, min(10, settings.exercisesPerWorkout))

        while chosen.count < count, !pool.isEmpty {
            let scored: [(Exercise, Double)] = pool.map { ex in
                let primary = ex.primary.map { muscleWeight[$0] ?? 0 }.reduce(0, +) / Double(ex.primary.count)
                var score = primary * 10
                if ex.isCompound { score += chosen.count < 2 ? 4 : 1 }
                if recentIDs.contains(ex.id) { score -= 2 }
                score += Double.random(in: 0...2.5)
                return (ex, score)
            }
            guard let best = scored.max(by: { $0.1 < $1.1 })?.0 else { break }
            chosen.append(best)
            pool.removeAll { $0.id == best.id }
            for m in best.primary { muscleWeight[m] = (muscleWeight[m] ?? 0) * 0.35 }
            for m in best.secondary { muscleWeight[m] = (muscleWeight[m] ?? 0) * 0.75 }
        }

        let ordered = chosen.filter(\.isCompound) + chosen.filter { !$0.isCompound }
        return Workout(title: focus.displayName,
                       exercises: ordered.map { makeEntry(for: $0) },
                       equipmentProfileName: settings.activeProfile.name)
    }

    /// Plans several upcoming sessions, simulating recovery between them.
    func planWeek(sessions: Int, daysBetween: Double = 2) -> [Workout] {
        var simulated = history
        var plan: [Workout] = []
        for i in 0..<sessions {
            let date = now.addingTimeInterval(Double(i) * daysBetween * 86_400)
            var gen = self
            gen.history = simulated
            gen.now = date
            var w = gen.generate()
            w.createdAt = date
            plan.append(w)
            var done = w
            done.finishedAt = date.addingTimeInterval(3600)
            for e in done.exercises.indices {
                for s in done.exercises[e].sets.indices { done.exercises[e].sets[s].done = true }
            }
            simulated.append(done)
        }
        return plan
    }

    func makeEntry(for ex: Exercise) -> WorkoutExercise {
        let goal = settings.goal
        let reps = ex.isCompound ? goal.targetReps : max(goal.targetReps, 10)
        let setCount = ex.isCompound ? goal.sets : 3
        let weight = suggestedWeight(for: ex, reps: reps)
        let sets = (0..<setCount).map { _ in LoggedSet(reps: reps, weight: weight) }
        return WorkoutExercise(exerciseID: ex.id, sets: sets, restSeconds: ex.isCompound ? goal.restSeconds : 60)
    }

    /// Next weight, based on the last session's best set (Epley 1RM) plus a small
    /// progression if every planned set was completed.
    func suggestedWeight(for ex: Exercise, reps: Int) -> Double {
        if ex.isBodyweight { return 0 }
        for workout in history.reversed() where workout.finishedAt != nil {
            guard let item = workout.exercises.first(where: { $0.exerciseID == ex.id }) else { continue }
            let done = item.sets.filter { $0.done && $0.reps > 0 && $0.weight > 0 }
            guard let best = done.max(by: { Self.oneRepMax($0) < Self.oneRepMax($1) }) else { continue }
            var target = Self.oneRepMax(best) / (1 + Double(reps) / 30)
            if item.sets.allSatisfy(\.done) { target *= 1.025 }
            return roundToStep(target)
        }
        return defaultWeight(for: ex)
    }

    static func oneRepMax(_ s: LoggedSet) -> Double { s.weight * (1 + Double(s.reps) / 30) }

    private func roundToStep(_ w: Double) -> Double {
        let step = settings.weightStep
        return max(step, (w / step).rounded() * step)
    }

    private func defaultWeight(for ex: Exercise) -> Double {
        let lb: Double
        if ex.equipment.contains(.barbell) { lb = ex.isCompound ? 65 : 45 }
        else if ex.equipment.contains(.machine) || ex.equipment.contains(.cable) { lb = ex.isCompound ? 60 : 30 }
        else if ex.equipment.contains(.kettlebell) { lb = 25 }
        else if ex.equipment.contains(.dumbbell) { lb = ex.isCompound ? 25 : 15 }
        else { lb = 0 }
        return settings.useKilograms ? roundToStep(lb * 0.4536) : lb
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
