import Foundation

// MARK: - Decoding helper (new fields get defaults so older saved data still loads)

extension KeyedDecodingContainer {
    func value<T: Decodable>(_ key: Key, _ fallback: @autoclosure () -> T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback()
    }
}

// MARK: - Muscles

enum Muscle: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case chest, frontDelts, sideDelts, rearDelts, triceps, biceps, forearms, abs, obliques
    case traps, upperBack, lats, lowerBack
    case glutes, quads, hamstrings, adductors, calves

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .frontDelts: return "Front Delts"
        case .sideDelts: return "Side Delts"
        case .rearDelts: return "Rear Delts"
        case .triceps: return "Triceps"
        case .biceps: return "Biceps"
        case .forearms: return "Forearms"
        case .abs: return "Abs"
        case .obliques: return "Obliques"
        case .traps: return "Traps"
        case .upperBack: return "Upper Back"
        case .lats: return "Lats"
        case .lowerBack: return "Lower Back"
        case .glutes: return "Glutes"
        case .quads: return "Quads"
        case .hamstrings: return "Hamstrings"
        case .adductors: return "Adductors"
        case .calves: return "Calves"
        }
    }

    /// Hours for this muscle to fully recover from a hard session.
    var recoveryHours: Double {
        switch self {
        case .quads, .hamstrings, .glutes, .lowerBack, .chest, .lats, .upperBack: return 72
        case .abs, .obliques, .calves, .forearms: return 36
        default: return 48
        }
    }

    var group: MuscleGroup {
        switch self {
        case .chest: return .chest
        case .frontDelts, .sideDelts, .rearDelts: return .shoulders
        case .triceps, .biceps, .forearms: return .arms
        case .abs, .obliques: return .core
        case .traps, .upperBack, .lats, .lowerBack: return .back
        case .glutes, .quads, .hamstrings, .adductors, .calves: return .legs
        }
    }
}

enum MuscleGroup: String, CaseIterable, Identifiable, Sendable {
    case chest, back, shoulders, arms, legs, core, cardio
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

// MARK: - Equipment

enum Equipment: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    // Free weights and stations
    case barbell, dumbbell, kettlebell, bench, pullupBar, dipStation, bands, bodyweight
    // Cables and machines
    case abWheel
    case cable, smith, legPress, hackSquat, legExtension, legCurl, chestPress, pecDeck, shoulderPress
    case latPulldown, cableRow, rowMachine, assistedPullup, preacher, abductor, adductor, calfMachine
    case abCrunch, backExtension
    // Cardio machines
    case treadmill, elliptical
    /// Older saved setups used one "machines" switch; it still means "every machine".
    case machine

    var id: String { rawValue }

    static let freeWeights: [Equipment] = [.barbell, .dumbbell, .kettlebell, .bench, .pullupBar, .dipStation, .bands, .abWheel]
    static let machines: [Equipment] = [.cable, .smith, .legPress, .hackSquat, .legExtension, .legCurl, .chestPress,
                                        .pecDeck, .shoulderPress, .latPulldown, .cableRow, .rowMachine, .assistedPullup,
                                        .preacher, .abductor, .adductor, .calfMachine, .abCrunch, .backExtension]
    static let cardioMachines: [Equipment] = [.treadmill, .elliptical]
    static var selectable: [Equipment] { freeWeights + machines + cardioMachines }

    var displayName: String {
        switch self {
        case .barbell: return "Barbell & Plates"
        case .dumbbell: return "Dumbbells"
        case .kettlebell: return "Kettlebells"
        case .bench: return "Bench"
        case .pullupBar: return "Pull-up Bar"
        case .dipStation: return "Dip Station"
        case .bands: return "Resistance Bands"
        case .abWheel: return "Ab Wheel"
        case .bodyweight: return "Bodyweight"
        case .cable: return "Cable Station"
        case .smith: return "Smith Machine"
        case .legPress: return "Leg Press"
        case .hackSquat: return "Hack Squat"
        case .legExtension: return "Leg Extension"
        case .legCurl: return "Leg Curl"
        case .chestPress: return "Chest Press Machine"
        case .pecDeck: return "Pec Deck / Rear Delt"
        case .shoulderPress: return "Shoulder Press Machine"
        case .latPulldown: return "Lat Pulldown"
        case .cableRow: return "Seated Cable Row"
        case .rowMachine: return "Chest-Supported Row"
        case .assistedPullup: return "Assisted Pull-up / Dip"
        case .preacher: return "Preacher Curl"
        case .abductor: return "Hip Abduction"
        case .adductor: return "Hip Adduction"
        case .calfMachine: return "Calf Raise Machine"
        case .abCrunch: return "Ab Crunch Machine"
        case .backExtension: return "Back Extension / Roman Chair"
        case .treadmill: return "Treadmill"
        case .elliptical: return "Elliptical"
        case .machine: return "All Machines"
        }
    }

    var symbol: String {
        switch self {
        case .barbell: return "figure.strengthtraining.traditional"
        case .dumbbell: return "dumbbell.fill"
        case .kettlebell: return "scalemass.fill"
        case .bench: return "bed.double.fill"
        case .pullupBar: return "figure.climbing"
        case .dipStation: return "arrow.down.to.line"
        case .bands: return "lasso"
        case .abWheel: return "circle.circle"
        case .bodyweight: return "figure.walk"
        case .cable: return "cable.connector"
        case .treadmill: return "figure.run"
        case .elliptical: return "figure.elliptical"
        default: return "gearshape.2.fill"
        }
    }

    /// True when the given set of equipment covers this item.
    func isCovered(by have: Set<Equipment>) -> Bool {
        if self == .bodyweight || have.contains(self) { return true }
        if have.contains(.machine), Equipment.machines.contains(self) || Equipment.cardioMachines.contains(self) { return true }
        // A cable station can do pulldowns and seated rows with the right attachment.
        if (self == .latPulldown || self == .cableRow), have.contains(.cable) { return true }
        return false
    }
}

/// A named set of equipment, e.g. "Home" or "Gym".
struct EquipmentProfile: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var equipment: Set<Equipment>
    /// What the user typed, e.g. "pec deck, smith machine, leg press".
    var machineText: String = ""

    init(id: UUID = UUID(), name: String, equipment: Set<Equipment>, machineText: String = "") {
        self.id = id; self.name = name; self.equipment = equipment; self.machineText = machineText
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, UUID())
        name = c.value(.name, "Setup")
        let raw: [String] = c.value(.equipment, [])
        equipment = Set(raw.compactMap(Equipment.init(rawValue:)))
        machineText = c.value(.machineText, "")
    }

    static let gym = EquipmentProfile(name: "Gym", equipment: Set(Equipment.selectable))
    static let home = EquipmentProfile(name: "Home", equipment: [.dumbbell, .bands, .pullupBar, .bodyweight])
}

// MARK: - Profile

enum TrainingGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case muscle, strength, fatLoss, endurance

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .strength: return "Get Stronger"
        case .muscle: return "Build Muscle"
        case .fatLoss: return "Lose Fat"
        case .endurance: return "Endurance"
        }
    }
    var blurb: String {
        switch self {
        case .strength: return "Heavier weights, fewer reps, longer rest."
        case .muscle: return "Moderate weights, 8–12 reps."
        case .fatLoss: return "Keep strength while losing fat. Shorter rests."
        case .endurance: return "Lighter weights, 15+ reps."
        }
    }
    var sets: Int { self == .strength ? 4 : 3 }
    var targetReps: Int {
        switch self {
        case .strength: return 5
        case .muscle: return 10
        case .fatLoss: return 12
        case .endurance: return 15
        }
    }
    var restSeconds: Int {
        switch self {
        case .strength: return 180
        case .muscle: return 90
        case .fatLoss: return 60
        case .endurance: return 45
        }
    }
}

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case beginner, intermediate, advanced

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var blurb: String {
        switch self {
        case .beginner: return "New to lifting or less than 6 months of steady training."
        case .intermediate: return "6 months to 2 years of regular training."
        case .advanced: return "2+ years, comfortable with heavy compound lifts."
        }
    }
    /// Multiplier on intermediate strength standards.
    var strengthFactor: Double {
        switch self {
        case .beginner: return 0.55
        case .intermediate: return 1.0
        case .advanced: return 1.4
        }
    }
}

enum Sex: String, Codable, CaseIterable, Identifiable, Sendable {
    case male, female, unspecified
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .unspecified: return "Prefer not to say"
        }
    }
    func strengthFactor(lowerBody: Bool) -> Double {
        switch self {
        case .male: return 1.0
        case .female: return lowerBody ? 0.75 : 0.62
        case .unspecified: return lowerBody ? 0.88 : 0.82
        }
    }
}

struct WeighIn: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var date: Date
    var kg: Double
}

/// A strength goal, measured as an estimated one-rep max in the user's weight unit.
struct StrengthTarget: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var exerciseID: String
    var target: Double
    var start: Double
    var createdAt: Date = Date()
}

// MARK: - Splits and programs

enum SplitFocus: String, Codable, CaseIterable, Identifiable, Sendable {
    case auto, fullBody, upper, lower, push, pull, legs, chest, back, shoulders, arms, shouldersArms, cardio

    var id: String { rawValue }
    static var pickable: [SplitFocus] { allCases.filter { $0 != .auto } }

    var displayName: String {
        switch self {
        case .auto: return "Auto (by recovery)"
        case .fullBody: return "Full Body"
        case .upper: return "Upper Body"
        case .lower: return "Lower Body"
        case .push: return "Push"
        case .pull: return "Pull"
        case .legs: return "Legs"
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .arms: return "Arms"
        case .shouldersArms: return "Shoulders & Arms"
        case .cardio: return "Cardio"
        }
    }
    var muscles: [Muscle] {
        switch self {
        case .auto, .fullBody: return Muscle.allCases
        case .upper: return [.chest, .frontDelts, .sideDelts, .rearDelts, .triceps, .biceps, .forearms, .traps, .upperBack, .lats]
        case .lower: return [.glutes, .quads, .hamstrings, .adductors, .calves, .lowerBack, .abs, .obliques]
        case .push: return [.chest, .frontDelts, .sideDelts, .triceps]
        case .pull: return [.lats, .upperBack, .rearDelts, .traps, .biceps, .forearms]
        case .legs: return [.quads, .hamstrings, .glutes, .adductors, .calves]
        case .chest: return [.chest, .frontDelts]
        case .back: return [.lats, .upperBack, .traps, .lowerBack, .rearDelts]
        case .shoulders: return [.frontDelts, .sideDelts, .rearDelts, .traps]
        case .arms: return [.biceps, .triceps, .forearms]
        case .shouldersArms: return [.frontDelts, .sideDelts, .rearDelts, .biceps, .triceps]
        case .cardio: return []
        }
    }
}

enum ProgramSplit: String, Codable, CaseIterable, Identifiable, Sendable {
    case fullBody, upperLower, pushPullLegs, upperLowerPPL, broSplit

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .fullBody: return "Full Body"
        case .upperLower: return "Upper / Lower"
        case .pushPullLegs: return "Push / Pull / Legs"
        case .upperLowerPPL: return "Upper / Lower + PPL"
        case .broSplit: return "Body-Part Split"
        }
    }
    var blurb: String {
        switch self {
        case .fullBody: return "Every muscle each session. Best for 2–3 days a week."
        case .upperLower: return "Alternate upper and lower body. Great at 4 days."
        case .pushPullLegs: return "Push muscles, pull muscles, legs. Best at 3 or 6 days."
        case .upperLowerPPL: return "Upper, Lower, Push, Pull, Legs. Built for 5 days."
        case .broSplit: return "One or two body parts per day. For 4–6 days."
        }
    }

    static func recommended(days: Int) -> ProgramSplit {
        switch days {
        case ...3: return .fullBody
        case 4: return .upperLower
        case 5: return .upperLowerPPL
        default: return .pushPullLegs
        }
    }

    func schedule(days n: Int) -> [SplitFocus] {
        let days = max(1, min(7, n))
        let cycle: [SplitFocus]
        switch self {
        case .fullBody:
            cycle = [.fullBody]
        case .upperLower:
            cycle = days == 3 ? [.upper, .lower, .fullBody] : [.upper, .lower]
        case .pushPullLegs:
            cycle = days == 4 ? [.push, .pull, .legs, .upper] : (days == 5 ? [.push, .pull, .legs, .upper, .lower] : [.push, .pull, .legs])
        case .upperLowerPPL:
            cycle = days <= 3 ? [.upper, .lower, .fullBody] : (days == 4 ? [.upper, .lower, .push, .pull] : [.upper, .lower, .push, .pull, .legs, .fullBody])
        case .broSplit:
            switch days {
            case ...3: cycle = [.push, .pull, .legs]
            case 4: cycle = [.chest, .back, .legs, .shouldersArms]
            default: cycle = [.chest, .back, .legs, .shoulders, .arms, .legs]
            }
        }
        return (0..<days).map { cycle[$0 % cycle.count] }
    }

    /// Suggested weekdays (1 = Monday) for a number of training days.
    static func suggestedWeekdays(days: Int) -> [Int] {
        switch days {
        case 1: return [1]
        case 2: return [1, 4]
        case 3: return [1, 3, 5]
        case 4: return [1, 2, 4, 5]
        case 5: return [1, 2, 3, 5, 6]
        case 6: return [1, 2, 3, 4, 5, 6]
        default: return [1, 2, 3, 4, 5, 6, 7]
        }
    }
}

enum CardioPlan: String, Codable, CaseIterable, Identifiable, Sendable {
    case off, warmup, finisher

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .off: return "No cardio"
        case .warmup: return "Warm-up (5–10 min)"
        case .finisher: return "Finisher (10–20 min)"
        }
    }
}

// MARK: - Exercises and workouts

struct Exercise: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let primary: [Muscle]
    let secondary: [Muscle]
    /// Everything needed to do the exercise.
    let equipment: [Equipment]
    let isCompound: Bool
    /// Custom exercises: the user's own how-to notes.
    var notes: String? = nil
    /// Custom exercises: a built-in exercise whose form animation and cues to borrow.
    var formLike: String? = nil

    var isCustom: Bool { id.hasPrefix("custom_") }

    /// Exercises with no external load are logged as reps only.
    var isBodyweight: Bool {
        equipment.allSatisfy { [.bodyweight, .pullupBar, .dipStation, .bench, .bands, .assistedPullup, .abWheel].contains($0) }
    }
    /// Holds like the plank: the "reps" field is seconds.
    var isTimed: Bool { ExerciseLibrary.timedIDs.contains(id) }
    var usesMachine: Bool { equipment.contains { Equipment.machines.contains($0) } }
    var isCardio: Bool { equipment.contains { Equipment.cardioMachines.contains($0) } }
    var group: MuscleGroup { isCardio ? .cardio : (primary.first?.group ?? .core) }
    var isLowerBody: Bool { primary.contains { $0.group == .legs } }
}

struct LoggedSet: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var reps: Int
    var weight: Double
    var done: Bool = false
    // Cardio entries use these instead of reps/weight.
    var minutes: Double?
    /// Treadmill: speed (mph or km/h). Elliptical: resistance level.
    var speed: Double?
    /// Treadmill incline, %.
    var incline: Double?
    /// Miles or km.
    var distance: Double?
}

struct WorkoutExercise: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var exerciseID: String
    var sets: [LoggedSet]
    var restSeconds: Int
    /// What the app suggested when the workout was planned.
    var suggestedWeight: Double?
    var targetReps: Int?
    /// Extra instructions, e.g. the interval pattern for cardio.
    var note: String?
    /// Cardio target minutes when it was planned.
    var targetMinutes: Double?
    /// Neighbouring exercises with the same group are a superset (2) or circuit (3+).
    var groupID: UUID?

    init(id: UUID = UUID(), exerciseID: String, sets: [LoggedSet], restSeconds: Int, suggestedWeight: Double? = nil,
         targetReps: Int? = nil, note: String? = nil, targetMinutes: Double? = nil, groupID: UUID? = nil) {
        self.id = id; self.exerciseID = exerciseID; self.sets = sets; self.restSeconds = restSeconds
        self.suggestedWeight = suggestedWeight; self.targetReps = targetReps; self.note = note; self.targetMinutes = targetMinutes
        self.groupID = groupID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, UUID())
        exerciseID = try c.decode(String.self, forKey: .exerciseID)
        sets = c.value(.sets, [])
        restSeconds = c.value(.restSeconds, 90)
        suggestedWeight = c.value(.suggestedWeight, nil)
        targetReps = c.value(.targetReps, nil)
        note = c.value(.note, nil)
        targetMinutes = c.value(.targetMinutes, nil)
        groupID = c.value(.groupID, nil)
    }

    var exercise: Exercise? { ExerciseLibrary.byID[exerciseID] }
    var name: String { exercise?.name ?? (exerciseID.hasPrefix("custom_") ? "Deleted exercise" : exerciseID) }
    var completedSets: Int { sets.filter(\.done).count }
    var isCardio: Bool { exercise?.isCardio ?? false }
    var cardioMinutes: Double { sets.filter(\.done).compactMap(\.minutes).reduce(0, +) }
}

struct Workout: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var title: String
    var createdAt: Date = Date()
    var startedAt: Date?
    var finishedAt: Date?
    var updatedAt: Date = Date()
    var exercises: [WorkoutExercise]
    var equipmentProfileName: String?
    var calories: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    /// Where the calorie number came from: "watch" (Apple Watch sensors), "heartRate" (from heart rate) or "estimate".
    var calorieSource: String?
    var savedToHealth: Bool = false
    /// Program day (0-based) this workout was for.
    var programDay: Int?

    init(id: UUID = UUID(), title: String, createdAt: Date = Date(), exercises: [WorkoutExercise],
         equipmentProfileName: String? = nil, programDay: Int? = nil) {
        self.id = id; self.title = title; self.createdAt = createdAt; self.exercises = exercises
        self.equipmentProfileName = equipmentProfileName; self.programDay = programDay
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, UUID())
        title = c.value(.title, "Workout")
        createdAt = c.value(.createdAt, Date())
        startedAt = c.value(.startedAt, nil)
        finishedAt = c.value(.finishedAt, nil)
        updatedAt = c.value(.updatedAt, Date())
        exercises = c.value(.exercises, [])
        equipmentProfileName = c.value(.equipmentProfileName, nil)
        calories = c.value(.calories, nil)
        averageHeartRate = c.value(.averageHeartRate, nil)
        maxHeartRate = c.value(.maxHeartRate, nil)
        calorieSource = c.value(.calorieSource, nil)
        savedToHealth = c.value(.savedToHealth, false)
        programDay = c.value(.programDay, nil)
    }

    var completedSetCount: Int { exercises.reduce(0) { $0 + $1.completedSets } }
    var volume: Double {
        exercises.flatMap(\.sets).filter(\.done).reduce(0) { $0 + $1.weight * Double($1.reps) }
    }
    var duration: TimeInterval? {
        guard let s = startedAt, let f = finishedAt else { return nil }
        return f.timeIntervalSince(s)
    }
}

// MARK: - Settings

struct UserSettings: Codable, Equatable, Sendable {
    // Training
    var goal: TrainingGoal = .muscle
    var focus: SplitFocus = .auto
    var exercisesPerWorkout: Int = 5
    var sessionMinutes: Int = 45
    var useKilograms: Bool = false
    var healthEnabled: Bool = false
    var excludedExerciseIDs: Set<String> = []
    var exercisePreferences: [String: ExercisePreference] = [:]
    var injuries: Set<Injury> = []
    var customExercises: [Exercise] = []
    /// Pair accessory exercises into supersets when generating a workout.
    var autoSupersets: Bool = false
    var profiles: [EquipmentProfile] = [.gym, .home]
    var activeProfileID: UUID?
    var customMachineMap: [String: String] = [:]
    // Program
    var split: ProgramSplit = .fullBody
    var daysPerWeek: Int = 3
    var programDay: Int = 0
    // About you
    var onboarded: Bool = false
    var sex: Sex = .unspecified
    var heightCm: Double?
    var experience: ExperienceLevel = .beginner
    // Targets
    var targetWeightKg: Double?
    var targetDate: Date?
    var strengthTargets: [StrengthTarget] = []
    var weighInReminder: Bool = false
    // Cardio and looks
    var cardioPlan: CardioPlan = .off
    var abhiMode: Bool = false
    // Music
    var spotifyClientID: String = ""
    var spotifyPlaylistURI: String = ""

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = UserSettings()
        goal = c.value(.goal, d.goal)
        focus = c.value(.focus, d.focus)
        exercisesPerWorkout = c.value(.exercisesPerWorkout, d.exercisesPerWorkout)
        sessionMinutes = c.value(.sessionMinutes, d.sessionMinutes)
        useKilograms = c.value(.useKilograms, d.useKilograms)
        healthEnabled = c.value(.healthEnabled, d.healthEnabled)
        excludedExerciseIDs = c.value(.excludedExerciseIDs, d.excludedExerciseIDs)
        exercisePreferences = c.value(.exercisePreferences, d.exercisePreferences)
        injuries = c.value(.injuries, d.injuries)
        customExercises = c.value(.customExercises, d.customExercises)
        autoSupersets = c.value(.autoSupersets, d.autoSupersets)
        profiles = c.value(.profiles, d.profiles)
        activeProfileID = c.value(.activeProfileID, nil)
        customMachineMap = c.value(.customMachineMap, d.customMachineMap)
        split = c.value(.split, d.split)
        daysPerWeek = c.value(.daysPerWeek, d.daysPerWeek)
        programDay = c.value(.programDay, d.programDay)
        // Anyone with saved data from the first version has already set things up.
        onboarded = c.value(.onboarded, true)
        sex = c.value(.sex, d.sex)
        heightCm = c.value(.heightCm, nil)
        experience = c.value(.experience, d.experience)
        targetWeightKg = c.value(.targetWeightKg, nil)
        targetDate = c.value(.targetDate, nil)
        strengthTargets = c.value(.strengthTargets, d.strengthTargets)
        weighInReminder = c.value(.weighInReminder, d.weighInReminder)
        cardioPlan = c.value(.cardioPlan, d.cardioPlan)
        abhiMode = c.value(.abhiMode, d.abhiMode)
        spotifyClientID = c.value(.spotifyClientID, d.spotifyClientID)
        spotifyPlaylistURI = c.value(.spotifyPlaylistURI, d.spotifyPlaylistURI)
    }

    var activeProfile: EquipmentProfile {
        profiles.first { $0.id == activeProfileID } ?? profiles.first ?? .gym
    }
    var availableEquipment: Set<Equipment> { activeProfile.equipment.union([.bodyweight]) }
    var weightUnit: String { useKilograms ? "kg" : "lb" }
    var weightStep: Double { useKilograms ? 2.5 : 5 }
    var speedUnit: String { useKilograms ? "km/h" : "mph" }
    var distanceUnit: String { useKilograms ? "km" : "mi" }

    var schedule: [SplitFocus] { split.schedule(days: daysPerWeek) }
    var nextFocus: SplitFocus {
        let s = schedule
        return s[((programDay % s.count) + s.count) % s.count]
    }

    static func exercises(forMinutes m: Int) -> Int {
        switch m {
        case ..<35: return 4
        case ..<50: return 5
        case ..<65: return 6
        case ..<80: return 7
        default: return 8
        }
    }

    // Unit helpers (body weight is stored in kg).
    func displayWeight(kg: Double) -> Double { useKilograms ? kg : kg * 2.20462 }
    func kg(fromDisplay v: Double) -> Double { useKilograms ? v : v / 2.20462 }
}
