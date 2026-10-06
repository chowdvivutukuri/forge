import Foundation

/// How often the generator should pick an exercise. "Never" is `UserSettings.excludedExerciseIDs`.
enum ExercisePreference: String, Codable, CaseIterable, Sendable {
    case more, less

    var displayName: String { self == .more ? "More often" : "Less often" }
    var symbol: String { self == .more ? "hand.thumbsup" : "arrow.down.circle" }
}

/// A sore or injured area. Forge skips exercises that load it hard and picks gentler ones less often.
/// This is a general guide, not medical advice.
enum Injury: String, Codable, CaseIterable, Identifiable, Sendable {
    case shoulder, elbow, wrist, neck, lowerBack, hip, knee, ankle

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shoulder: return "Shoulder"
        case .elbow: return "Elbow"
        case .wrist: return "Wrist"
        case .neck: return "Neck"
        case .lowerBack: return "Lower back"
        case .hip: return "Hip"
        case .knee: return "Knee"
        case .ankle: return "Ankle"
        }
    }

    /// Exercises that load this area hard; never suggested while it's marked.
    var avoid: Set<String> {
        switch self {
        case .shoulder:
            return ["bb_ohp", "db_ohp", "kb_press", "machine_shoulder", "pike_pushup", "dips", "bb_bench", "bb_incline",
                    "smith_bench", "close_grip_bench", "db_fly", "pec_deck", "kb_windmill", "skullcrusher", "bench_dip"]
        case .elbow:
            return ["skullcrusher", "close_grip_bench", "db_oh_ext", "diamond_pushup", "dips", "bb_curl", "preacher_curl", "bench_dip"]
        case .wrist:
            return ["pushup", "diamond_pushup", "pike_pushup", "front_squat", "bb_curl", "skullcrusher", "dips", "kb_windmill",
                    "archer_pushup", "l_sit", "bench_dip"]
        case .neck:
            return ["bb_shrug", "db_shrug", "back_squat", "crunch", "bb_ohp"]
        case .lowerBack:
            return ["deadlift", "bb_row", "bb_rdl", "back_squat", "band_good_morning", "kb_swing", "back_ext",
                    "russian_twist", "front_squat", "bb_shrug", "ab_wheel"]
        case .hip:
            return ["split_squat", "db_lunge", "bw_lunge", "deadlift", "back_squat", "copenhagen", "adductor_machine", "pistol_squat",
                    "abductor_machine"]
        case .knee:
            return ["leg_ext", "split_squat", "db_lunge", "bw_lunge", "hack_squat", "back_squat", "front_squat",
                    "smith_squat", "tm_run", "tm_intervals", "pistol_squat", "bw_split_squat"]
        case .ankle:
            return ["db_lunge", "bw_lunge", "split_squat", "bw_calf", "tm_run", "tm_intervals", "pistol_squat"]
        }
    }

    /// Still fine for most people, but picked less often.
    var caution: Set<String> {
        switch self {
        case .shoulder:
            return ["db_bench", "db_incline", "pushup", "pullup", "chinup", "db_lateral", "cable_lateral", "db_oh_ext",
                    "machine_chest", "cable_fly", "bb_row", "plank", "side_plank", "ab_wheel",
                    "hanging_knee_raise", "hanging_leg_raise"]
        case .elbow:
            return ["pushdown", "chinup", "pullup", "db_curl", "hammer_curl", "cable_curl", "bb_bench"]
        case .wrist:
            return ["bb_bench", "close_grip_bench", "bb_ohp", "db_curl", "kb_press", "kb_swing"]
        case .neck:
            return ["deadlift", "hanging_leg_raise", "db_ohp", "bb_row"]
        case .lowerBack:
            return ["db_rdl", "bb_ohp", "hanging_leg_raise", "db_row", "goblet_squat", "leg_press", "hip_thrust"]
        case .hip:
            return ["hip_thrust", "bb_rdl", "leg_press", "kb_swing", "goblet_squat", "front_squat", "hack_squat"]
        case .knee:
            return ["leg_press", "goblet_squat", "kb_goblet", "bw_squat", "leg_curl", "seated_leg_curl"]
        case .ankle:
            return ["calf_machine", "db_calf", "back_squat", "goblet_squat", "kb_goblet", "bw_squat"]
        }
    }
}

extension UserSettings {
    /// Exercises the generator must never pick: hidden ones plus anything an injury rules out.
    var blockedExerciseIDs: Set<String> {
        injuries.reduce(excludedExerciseIDs) { $0.union($1.avoid) }
    }

    /// Score adjustment for the generator: liked exercises up, disliked or injury-caution ones down.
    func preferenceBonus(for id: String) -> Double {
        var bonus = 0.0
        switch exercisePreferences[id] {
        case .more: bonus += 4
        case .less: bonus -= 5
        case nil: break
        }
        if injuries.contains(where: { $0.caution.contains(id) }) { bonus -= 3 }
        return bonus
    }

    /// The injury that blocks this exercise, if any.
    func blockingInjury(_ id: String) -> Injury? {
        Injury.allCases.first { injuries.contains($0) && $0.avoid.contains(id) }
    }
}
