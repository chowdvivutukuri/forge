import Foundation

/// Treadmill and elliptical prescriptions, progression and calorie estimates.
enum Cardio {
    enum Role { case warmup, finisher, session }

    static let treadmillIDs = ["tm_walk", "tm_run", "tm_intervals"]
    static let ellipticalIDs = ["ell_steady", "ell_intervals"]

    static func isInterval(_ id: String) -> Bool { id == "tm_intervals" || id == "ell_intervals" }
    static func isTreadmill(_ id: String) -> Bool { treadmillIDs.contains(id) }

    /// Picks which cardio exercise to do for a role, given what's available.
    static func choose(role: Role, settings: UserSettings, available: [Exercise], recentIDs: Set<String>) -> Exercise? {
        let ids = Set(available.filter(\.isCardio).map(\.id))
        guard !ids.isEmpty else { return nil }
        let level = settings.experience
        var order: [String]
        switch role {
        case .warmup:
            order = ["tm_walk", "ell_steady"]
        case .finisher:
            if settings.goal == .fatLoss && level != .beginner {
                order = ["tm_intervals", "ell_intervals", "tm_walk", "ell_steady"]
            } else if settings.goal == .endurance {
                order = ["tm_run", "ell_steady", "tm_walk"]
            } else {
                order = ["tm_walk", "ell_steady", "tm_intervals", "ell_intervals"]
            }
        case .session:
            switch level {
            case .beginner: order = ["tm_walk", "ell_steady", "ell_intervals"]
            case .intermediate: order = ["tm_walk", "ell_steady", "tm_intervals", "tm_run", "ell_intervals"]
            case .advanced: order = ["tm_run", "tm_intervals", "ell_intervals", "tm_walk", "ell_steady"]
            }
        }
        let usable = order.filter { ids.contains($0) }
        // Rotate away from what was done most recently.
        let pick = usable.first { !recentIDs.contains($0) } ?? usable.first
        return pick.flatMap { ExerciseLibrary.byID[$0] }
    }

    struct Plan {
        var minutes: Double
        var speed: Double?
        var incline: Double?
        var note: String?
    }

    /// Starting prescription in the user's units (mph or km/h; level for elliptical).
    static func basePlan(_ id: String, role: Role, settings: UserSettings) -> Plan {
        let lvl = settings.experience
        let i = lvl == .beginner ? 0 : (lvl == .intermediate ? 1 : 2)
        let km = settings.useKilograms
        func speed(_ mph: Double) -> Double { km ? (mph * 1.609 * 10).rounded() / 10 : mph }
        let minutesWarm = [6.0, 8.0, 10.0][i]
        let minutesFinish = [12.0, 15.0, 20.0][i]
        let minutesSession = [20.0, 30.0, 40.0][i]
        let minutes = role == .warmup ? minutesWarm : (role == .finisher ? minutesFinish : minutesSession)
        switch id {
        case "tm_walk":
            let sp = role == .warmup ? [2.8, 3.0, 3.2][i] : [3.0, 3.3, 3.5][i]
            let inc = role == .warmup ? [2.0, 3.0, 4.0][i] : [6.0, 9.0, 12.0][i]
            return Plan(minutes: minutes, speed: speed(sp), incline: inc, note: nil)
        case "tm_run":
            return Plan(minutes: role == .session ? minutesSession : minutesFinish, speed: speed([5.0, 6.0, 7.0][i]), incline: 1, note: nil)
        case "tm_intervals":
            let rounds = [5.0, 6.0, 8.0][i]
            let fast = speed([6.0, 7.0, 8.0][i]), easy = speed(3.5)
            return Plan(minutes: rounds * 3, speed: fast, incline: 1,
                        note: "\(Int(rounds)) rounds: 1 min at \(fmt(fast)) \(settings.speedUnit), 2 min at \(fmt(easy)) \(settings.speedUnit)")
        case "ell_steady":
            let level = role == .warmup ? [3.0, 4.0, 5.0][i] : [4.0, 7.0, 10.0][i]
            return Plan(minutes: minutes, speed: level, incline: nil, note: nil)
        case "ell_intervals":
            let rounds = [5.0, 6.0, 8.0][i]
            let hard = [8.0, 12.0, 15.0][i], easy = [3.0, 5.0, 7.0][i]
            return Plan(minutes: rounds * 3, speed: hard, incline: nil,
                        note: "\(Int(rounds)) rounds: 1 min at level \(fmt(hard)), 2 min at level \(fmt(easy))")
        default:
            return Plan(minutes: minutes, speed: nil, incline: nil, note: nil)
        }
    }

    /// Next prescription: builds on what you actually logged last time.
    static func plan(_ id: String, role: Role, settings: UserSettings, last: LoggedSet?) -> Plan {
        var plan = basePlan(id, role: role, settings: settings)
        guard let last, last.done, let lastMin = last.minutes, lastMin > 0 else { return plan }
        let completed = lastMin >= plan.minutes - 0.5
        // Start from what you did, not what was suggested.
        if role != .warmup { plan.minutes = min(60, lastMin) }
        if let sp = last.speed { plan.speed = sp }
        if let inc = last.incline { plan.incline = inc }
        guard completed, role != .warmup else { return plan }
        let km = settings.useKilograms
        switch id {
        case "tm_walk":
            if let inc = plan.incline, inc < 15 { plan.incline = inc + 1 } else { plan.minutes = min(60, plan.minutes + 2) }
        case "tm_run":
            if let sp = plan.speed { plan.speed = sp + (km ? 0.3 : 0.2) }
        case "tm_intervals", "ell_intervals":
            plan.minutes = min(45, plan.minutes + 3)
        case "ell_steady":
            if let lv = plan.speed, lv < 20 { plan.speed = lv + 1 } else { plan.minutes = min(60, plan.minutes + 2) }
        default:
            break
        }
        if isInterval(id) {
            let rounds = Int((plan.minutes / 3).rounded())
            plan.note = plan.note.map { note in
                let rest = note.split(separator: ":", maxSplits: 1).dropFirst().joined()
                return "\(rounds) rounds:\(rest)"
            }
        }
        return plan
    }

    /// Estimated kcal. Treadmill uses the ACSM walking/running equations; elliptical uses METs by level.
    static func calories(_ id: String, minutes: Double, speed: Double?, incline: Double?, bodyKg: Double, useKm: Bool) -> Double {
        guard minutes > 0 else { return 0 }
        if isTreadmill(id) {
            let raw = speed ?? 3.0
            let mph = useKm ? raw / 1.609 : raw
            let metersPerMin = mph * 26.8224
            let grade = (incline ?? 0) / 100
            let running = mph >= 4.5
            let horizontal: Double = (running ? 0.2 : 0.1) * metersPerMin
            let vertical: Double = (running ? 0.9 : 1.8) * metersPerMin * grade
            let vo2: Double = horizontal + vertical + 3.5
            let litres: Double = vo2 * bodyKg / 1000
            var kcal: Double = litres * 5 * minutes
            if isInterval(id) { kcal *= 0.8 }  // two-thirds of the time is easy
            return kcal
        }
        let level = speed ?? 5
        let clamped: Double = Swift.min(20, Swift.max(1, level))
        let met: Double = 4.5 + clamped * 0.2
        let perMinute: Double = met * 3.5 * bodyKg / 200
        var kcal: Double = perMinute * minutes
        if isInterval(id) { kcal *= 0.9 }
        return kcal
    }

    static func distance(_ id: String, minutes: Double, speed: Double?) -> Double? {
        guard isTreadmill(id), let sp = speed, !isInterval(id) else { return nil }
        return (sp * minutes / 60 * 100).rounded() / 100
    }

    static func fmt(_ v: Double) -> String { v.formatted(.number.precision(.fractionLength(0...1))) }

    /// One-line summary such as "20 min · 3.3 mph · 9%".
    static func summary(_ item: WorkoutExercise, settings: UserSettings) -> String {
        guard let s = item.sets.first else { return "" }
        var parts: [String] = []
        if let m = s.minutes { parts.append("\(fmt(m)) min") }
        if let sp = s.speed {
            parts.append(isTreadmill(item.exerciseID) ? "\(fmt(sp)) \(settings.speedUnit)" : "level \(fmt(sp))")
        }
        if let inc = s.incline, inc > 0 { parts.append("\(fmt(inc))% incline") }
        return parts.joined(separator: " · ")
    }
}
