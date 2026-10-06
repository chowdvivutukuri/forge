import Foundation

enum ExerciseLibrary {
    private static func ex(_ id: String, _ name: String, _ primary: [Muscle], _ secondary: [Muscle] = [],
                           _ equipment: [Equipment], compound: Bool) -> Exercise {
        Exercise(id: id, name: name, primary: primary, secondary: secondary, equipment: equipment, isCompound: compound)
    }

    static let builtIn: [Exercise] = [
        // Chest
        ex("bb_bench", "Barbell Bench Press", [.chest], [.frontDelts, .triceps], [.barbell, .bench], compound: true),
        ex("bb_incline", "Incline Barbell Press", [.chest, .frontDelts], [.triceps], [.barbell, .bench], compound: true),
        ex("db_bench", "Dumbbell Bench Press", [.chest], [.frontDelts, .triceps], [.dumbbell, .bench], compound: true),
        ex("db_incline", "Incline Dumbbell Press", [.chest, .frontDelts], [.triceps], [.dumbbell, .bench], compound: true),
        ex("db_floor_press", "Dumbbell Floor Press", [.chest], [.triceps], [.dumbbell], compound: true),
        ex("db_fly", "Dumbbell Fly", [.chest], [.frontDelts], [.dumbbell, .bench], compound: false),
        ex("cable_fly", "Cable Fly", [.chest], [.frontDelts], [.cable], compound: false),
        ex("machine_chest", "Machine Chest Press", [.chest], [.triceps, .frontDelts], [.chestPress], compound: true),
        ex("pec_deck", "Pec Deck Fly", [.chest], [.frontDelts], [.pecDeck], compound: false),
        ex("smith_bench", "Smith Machine Bench Press", [.chest], [.frontDelts, .triceps], [.smith, .bench], compound: true),
        ex("pushup", "Push-up", [.chest], [.triceps, .frontDelts, .abs], [.bodyweight], compound: true),
        ex("band_press", "Banded Chest Press", [.chest], [.triceps], [.bands], compound: true),
        ex("dips", "Dips", [.chest, .triceps], [.frontDelts], [.dipStation], compound: true),

        // Shoulders
        ex("bb_ohp", "Overhead Press", [.frontDelts], [.sideDelts, .triceps, .traps], [.barbell], compound: true),
        ex("db_ohp", "Dumbbell Shoulder Press", [.frontDelts], [.sideDelts, .triceps], [.dumbbell], compound: true),
        ex("kb_press", "Kettlebell Press", [.frontDelts], [.sideDelts, .triceps], [.kettlebell], compound: true),
        ex("machine_shoulder", "Machine Shoulder Press", [.frontDelts], [.sideDelts, .triceps], [.shoulderPress], compound: true),
        ex("pike_pushup", "Pike Push-up", [.frontDelts], [.triceps], [.bodyweight], compound: true),
        ex("db_lateral", "Dumbbell Lateral Raise", [.sideDelts], [], [.dumbbell], compound: false),
        ex("cable_lateral", "Cable Lateral Raise", [.sideDelts], [], [.cable], compound: false),
        ex("band_lateral", "Band Lateral Raise", [.sideDelts], [], [.bands], compound: false),
        ex("db_rear_fly", "Rear Delt Fly", [.rearDelts], [.upperBack], [.dumbbell], compound: false),
        ex("reverse_fly_machine", "Reverse Pec Deck", [.rearDelts], [.upperBack, .traps], [.pecDeck], compound: false),
        ex("face_pull", "Face Pull", [.rearDelts], [.traps, .upperBack], [.cable], compound: false),
        ex("band_pull_apart", "Band Pull-Apart", [.rearDelts], [.upperBack], [.bands], compound: false),

        // Arms
        ex("pushdown", "Triceps Pushdown", [.triceps], [], [.cable], compound: false),
        ex("skullcrusher", "Skull Crusher", [.triceps], [], [.barbell, .bench], compound: false),
        ex("db_oh_ext", "Overhead Dumbbell Extension", [.triceps], [], [.dumbbell], compound: false),
        ex("close_grip_bench", "Close-Grip Bench Press", [.triceps], [.chest], [.barbell, .bench], compound: true),
        ex("band_pushdown", "Band Pushdown", [.triceps], [], [.bands], compound: false),
        ex("diamond_pushup", "Diamond Push-up", [.triceps], [.chest], [.bodyweight], compound: true),
        ex("bb_curl", "Barbell Curl", [.biceps], [.forearms], [.barbell], compound: false),
        ex("db_curl", "Dumbbell Curl", [.biceps], [.forearms], [.dumbbell], compound: false),
        ex("hammer_curl", "Hammer Curl", [.biceps, .forearms], [], [.dumbbell], compound: false),
        ex("cable_curl", "Cable Curl", [.biceps], [.forearms], [.cable], compound: false),
        ex("band_curl", "Band Curl", [.biceps], [.forearms], [.bands], compound: false),
        ex("kb_curl", "Kettlebell Curl", [.biceps], [.forearms], [.kettlebell], compound: false),
        ex("preacher_curl", "Preacher Curl Machine", [.biceps], [.forearms], [.preacher], compound: false),

        // Back
        ex("pullup", "Pull-up", [.lats], [.biceps, .upperBack], [.pullupBar], compound: true),
        ex("chinup", "Chin-up", [.lats, .biceps], [.upperBack], [.pullupBar], compound: true),
        ex("assisted_pullup", "Assisted Pull-up", [.lats], [.biceps, .upperBack], [.assistedPullup], compound: true),
        ex("lat_pulldown", "Lat Pulldown", [.lats], [.biceps, .upperBack], [.latPulldown], compound: true),
        ex("band_pulldown", "Band Lat Pulldown", [.lats], [.biceps], [.bands], compound: true),
        ex("bb_row", "Barbell Row", [.upperBack, .lats], [.biceps, .rearDelts, .lowerBack], [.barbell], compound: true),
        ex("db_row", "One-Arm Dumbbell Row", [.lats, .upperBack], [.biceps, .rearDelts], [.dumbbell], compound: true),
        ex("kb_row", "Kettlebell Row", [.lats, .upperBack], [.biceps], [.kettlebell], compound: true),
        ex("cable_row", "Seated Cable Row", [.upperBack, .lats], [.biceps, .rearDelts], [.cableRow], compound: true),
        ex("machine_row", "Chest-Supported Machine Row", [.upperBack, .lats], [.biceps, .rearDelts], [.rowMachine], compound: true),
        ex("band_row", "Band Row", [.upperBack], [.lats, .biceps], [.bands], compound: true),
        ex("db_shrug", "Dumbbell Shrug", [.traps], [.forearms], [.dumbbell], compound: false),
        ex("bb_shrug", "Barbell Shrug", [.traps], [.forearms], [.barbell], compound: false),
        ex("back_ext", "Back Extension", [.lowerBack], [.glutes, .hamstrings], [.backExtension], compound: false),

        // Legs
        ex("back_squat", "Back Squat", [.quads, .glutes], [.adductors, .lowerBack, .hamstrings], [.barbell], compound: true),
        ex("front_squat", "Front Squat", [.quads], [.glutes, .abs], [.barbell], compound: true),
        ex("goblet_squat", "Goblet Squat", [.quads, .glutes], [.adductors, .abs], [.dumbbell], compound: true),
        ex("kb_goblet", "Kettlebell Goblet Squat", [.quads, .glutes], [.adductors], [.kettlebell], compound: true),
        ex("leg_press", "Leg Press", [.quads, .glutes], [.adductors], [.legPress], compound: true),
        ex("hack_squat", "Hack Squat", [.quads], [.glutes, .adductors], [.hackSquat], compound: true),
        ex("smith_squat", "Smith Machine Squat", [.quads, .glutes], [.adductors, .hamstrings], [.smith], compound: true),
        ex("split_squat", "Bulgarian Split Squat", [.quads, .glutes], [.adductors], [.dumbbell, .bench], compound: true),
        ex("db_lunge", "Walking Lunge", [.quads, .glutes], [.hamstrings], [.dumbbell], compound: true),
        ex("bw_squat", "Bodyweight Squat", [.quads], [.glutes], [.bodyweight], compound: true),
        ex("bw_lunge", "Reverse Lunge", [.quads, .glutes], [.hamstrings], [.bodyweight], compound: true),
        ex("leg_ext", "Leg Extension", [.quads], [], [.legExtension], compound: false),
        ex("deadlift", "Deadlift", [.hamstrings, .glutes, .lowerBack], [.traps, .forearms, .quads], [.barbell], compound: true),
        ex("bb_rdl", "Romanian Deadlift", [.hamstrings, .glutes], [.lowerBack], [.barbell], compound: true),
        ex("db_rdl", "Dumbbell Romanian Deadlift", [.hamstrings, .glutes], [.lowerBack], [.dumbbell], compound: true),
        ex("kb_swing", "Kettlebell Swing", [.glutes, .hamstrings], [.lowerBack, .abs], [.kettlebell], compound: true),
        ex("leg_curl", "Lying Leg Curl", [.hamstrings], [], [.legCurl], compound: false),
        ex("seated_leg_curl", "Seated Leg Curl", [.hamstrings], [], [.legCurl], compound: false),
        ex("band_good_morning", "Band Good Morning", [.hamstrings], [.lowerBack, .glutes], [.bands], compound: false),
        ex("hip_thrust", "Barbell Hip Thrust", [.glutes], [.hamstrings], [.barbell, .bench], compound: true),
        ex("glute_bridge", "Glute Bridge", [.glutes], [.hamstrings], [.bodyweight], compound: false),
        ex("adductor_machine", "Hip Adduction", [.adductors], [], [.adductor], compound: false),
        ex("abductor_machine", "Hip Abduction", [.glutes], [], [.abductor], compound: false),
        ex("copenhagen", "Copenhagen Plank", [.adductors], [.obliques], [.bench], compound: false),
        ex("calf_machine", "Machine Calf Raise", [.calves], [], [.calfMachine], compound: false),
        ex("db_calf", "Dumbbell Calf Raise", [.calves], [], [.dumbbell], compound: false),
        ex("bw_calf", "Single-Leg Calf Raise", [.calves], [], [.bodyweight], compound: false),

        // Core
        ex("hanging_leg_raise", "Hanging Leg Raise", [.abs], [.obliques, .forearms], [.pullupBar], compound: false),
        ex("cable_crunch", "Cable Crunch", [.abs], [], [.cable], compound: false),
        ex("ab_crunch_machine", "Ab Crunch Machine", [.abs], [], [.abCrunch], compound: false),
        ex("crunch", "Crunch", [.abs], [], [.bodyweight], compound: false),
        ex("dead_bug", "Dead Bug", [.abs], [.obliques], [.bodyweight], compound: false),
        ex("russian_twist", "Russian Twist", [.obliques], [.abs], [.bodyweight], compound: false),
        ex("pallof", "Pallof Press", [.obliques], [.abs], [.cable], compound: false),
        ex("band_pallof", "Band Pallof Press", [.obliques], [.abs], [.bands], compound: false),
        ex("kb_windmill", "Kettlebell Windmill", [.obliques], [.sideDelts, .hamstrings], [.kettlebell], compound: false),
        ex("plank", "Plank", [.abs], [.obliques, .frontDelts, .glutes], [.bodyweight], compound: false),
        ex("side_plank", "Side Plank", [.obliques], [.abs, .glutes], [.bodyweight], compound: false),
        ex("hollow_hold", "Hollow Hold", [.abs], [.obliques], [.bodyweight], compound: false),
        ex("hanging_knee_raise", "Hanging Knee Raise", [.abs], [.obliques, .forearms], [.pullupBar], compound: false),
        ex("ab_wheel", "Ab Wheel Rollout", [.abs], [.lats, .obliques], [.abWheel], compound: false),

        // Cardio
        ex("tm_walk", "Treadmill Incline Walk", [.glutes, .calves], [.hamstrings], [.treadmill], compound: false),
        ex("tm_run", "Treadmill Run", [.quads, .calves], [.hamstrings, .glutes], [.treadmill], compound: false),
        ex("tm_intervals", "Treadmill Intervals", [.quads, .calves], [.hamstrings, .glutes], [.treadmill], compound: false),
        ex("ell_steady", "Elliptical", [.quads, .glutes], [.hamstrings, .calves], [.elliptical], compound: false),
        ex("ell_intervals", "Elliptical Intervals", [.quads, .glutes], [.hamstrings, .calves], [.elliptical], compound: false),
    ]

    /// Holds measured in seconds instead of reps.
    static let timedIDs: Set<String> = ["plank", "side_plank", "hollow_hold", "l_sit", "dead_hang"]

    /// Exercises the user made. The iPhone and Watch stores set this from saved settings.
    static var custom: [Exercise] = [] {
        didSet {
            all = builtIn + custom
            byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        }
    }

    static private(set) var all: [Exercise] = builtIn
    static private(set) var byID: [String: Exercise] = Dictionary(uniqueKeysWithValues: builtIn.map { ($0.id, $0) })

    /// Exercises doable with the given equipment.
    static func available(with equipment: Set<Equipment>, excluding excluded: Set<String> = []) -> [Exercise] {
        let have = equipment.union([.bodyweight])
        return all.filter { ex in
            !excluded.contains(ex.id) && ex.equipment.allSatisfy { $0.isCovered(by: have) }
        }
    }
}
