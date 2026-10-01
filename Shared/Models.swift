import Foundation

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
}

// MARK: - Equipment

enum Equipment: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case barbell, dumbbell, kettlebell, cable, machine, bench, pullupBar, dipStation, bands, bodyweight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .barbell: return "Barbell & Plates"
        case .dumbbell: return "Dumbbells"
        case .kettlebell: return "Kettlebells"
        case .cable: return "Cable Machine"
        case .machine: return "Weight Machines"
        case .bench: return "Bench"
        case .pullupBar: return "Pull-up Bar"
        case .dipStation: return "Dip Station"
        case .bands: return "Resistance Bands"
        case .bodyweight: return "Bodyweight"
        }
    }

    var symbol: String {
        switch self {
        case .barbell: return "figure.strengthtraining.traditional"
        case .dumbbell: return "dumbbell.fill"
        case .kettlebell: return "scalemass.fill"
        case .cable: return "cable.connector"
        case .machine: return "gearshape.2.fill"
        case .bench: return "bed.double.fill"
        case .pullupBar: return "figure.climbing"
        case .dipStation: return "arrow.down.to.line"
        case .bands: return "lasso"
        case .bodyweight: return "figure.walk"
        }
    }
}

/// A named set of equipment, e.g. "Home" or "Gym".
struct EquipmentProfile: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var equipment: Set<Equipment>

    static let gym = EquipmentProfile(name: "Gym", equipment: Set(Equipment.allCases))
    static let home = EquipmentProfile(name: "Home", equipment: [.dumbbell, .bands, .pullupBar, .bodyweight])
}

// MARK: - Training options

enum TrainingGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case strength, muscle, endurance

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .muscle: return "Build Muscle"
        case .endurance: return "Endurance"
        }
    }
    var sets: Int {
        switch self {
        case .strength: return 4
        case .muscle: return 3
        case .endurance: return 3
        }
    }
    var targetReps: Int {
        switch self {
        case .strength: return 5
        case .muscle: return 10
        case .endurance: return 15
        }
    }
    var restSeconds: Int {
        switch self {
        case .strength: return 180
        case .muscle: return 90
        case .endurance: return 60
        }
    }
}

enum SplitFocus: String, Codable, CaseIterable, Identifiable, Sendable {
    case auto, fullBody, upper, lower, push, pull, legs

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .auto: return "Auto (by recovery)"
        case .fullBody: return "Full Body"
        case .upper: return "Upper Body"
        case .lower: return "Lower Body"
        case .push: return "Push"
        case .pull: return "Pull"
        case .legs: return "Legs"
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

    /// Exercises with no external load are logged as reps only.
    var isBodyweight: Bool {
        equipment.allSatisfy { [.bodyweight, .pullupBar, .dipStation, .bench, .bands].contains($0) }
    }
}

struct LoggedSet: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var reps: Int
    var weight: Double
    var done: Bool = false
}

struct WorkoutExercise: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var exerciseID: String
    var sets: [LoggedSet]
    var restSeconds: Int

    var exercise: Exercise? { ExerciseLibrary.byID[exerciseID] }
    var name: String { exercise?.name ?? exerciseID }
    var completedSets: Int { sets.filter(\.done).count }
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
    var savedToHealth: Bool = false

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
    var goal: TrainingGoal = .muscle
    var focus: SplitFocus = .auto
    var exercisesPerWorkout: Int = 5
    var useKilograms: Bool = false
    var healthEnabled: Bool = false
    var excludedExerciseIDs: Set<String> = []
    var profiles: [EquipmentProfile] = [.gym, .home]
    var activeProfileID: UUID?
    var spotifyClientID: String = ""
    var spotifyPlaylistURI: String = ""

    var activeProfile: EquipmentProfile {
        profiles.first { $0.id == activeProfileID } ?? profiles.first ?? .gym
    }
    var availableEquipment: Set<Equipment> { activeProfile.equipment.union([.bodyweight]) }
    var weightUnit: String { useKilograms ? "kg" : "lb" }
    var weightStep: Double { useKilograms ? 2.5 : 5 }
}
