import Foundation

/// Turns a typed list of gym machines ("pec deck, smith machine, leg press") into equipment types.
enum MachineCatalog {
    struct Match: Identifiable, Hashable {
        var id: String { text }
        let text: String
        let equipment: [Equipment]
    }

    struct Result {
        var recognized: [Match] = []
        var cardio: [String] = []
        var unknown: [String] = []
        var equipment: Set<Equipment> { Set(recognized.flatMap(\.equipment)) }
    }

    /// Checked in order; the first rule whose keywords appear wins, so specific names come first.
    private static let rules: [([String], [Equipment])] = [
        (["treadmill", "tread mill", "threadmill", "thread mill", "treadmil", "running machine", "incline trainer"], [.treadmill]),
        (["elliptical", "eliptical", "elliptic", "cross trainer", "cross-trainer", "crosstrainer", "arc trainer"], [.elliptical]),
        (["assisted", "gravitron"], [.assistedPullup]),
        (["smith"], [.smith]),
        (["hack squat", "hack-squat", "pendulum", "v-squat", "v squat", "belt squat"], [.hackSquat]),
        (["leg press", "legpress", "sled press", "45 degree", "45°"], [.legPress]),
        (["leg extension", "leg ext", "quad extension", "knee extension"], [.legExtension]),
        (["leg curl", "hamstring curl", "lying curl", "seated curl", "prone curl", "hamstring"], [.legCurl]),
        (["abductor/adductor", "adductor/abductor", "abduction/adduction", "inner/outer", "outer/inner"], [.abductor, .adductor]),
        (["abduct", "outer thigh", "hip abduction", "glute machine"], [.abductor]),
        (["adduct", "inner thigh"], [.adductor]),
        (["calf"], [.calfMachine]),
        (["rear delt", "reverse fly", "reverse pec", "reverse deck"], [.pecDeck]),
        (["pec deck", "pec fly", "pec-deck", "butterfly", "chest fly machine", "fly machine", "pec machine"], [.pecDeck]),
        (["chest press", "bench press machine", "incline press machine", "decline press machine", "iso-lateral bench",
          "iso lateral bench", "chest machine", "hammer strength chest"], [.chestPress]),
        (["shoulder press", "overhead press machine", "military press machine", "delt press"], [.shoulderPress]),
        (["lateral raise machine", "lateral machine"], [.shoulderPress]),
        (["lat pull", "pulldown", "pull down", "pull-down", "lat machine"], [.latPulldown]),
        (["seated row", "cable row", "low row", "row station"], [.cableRow]),
        (["chest supported", "chest-supported", "t-bar", "t bar", "tbar", "iso-lateral row", "iso lateral row", "row machine",
          "machine row", "high row"], [.rowMachine]),
        (["preacher", "bicep curl machine", "biceps curl machine", "arm curl", "curl machine"], [.preacher]),
        (["ab crunch", "abdominal", "ab machine", "crunch machine", "torso rotation"], [.abCrunch]),
        (["back extension", "hyperextension", "hyper extension", "roman chair", "glute ham", "ghd"], [.backExtension]),
        (["cable", "crossover", "cross over", "functional trainer", "pulley", "dual adjustable"], [.cable]),
        (["captain", "power tower", "vkr", "knee raise station"], [.pullupBar, .dipStation]),
        (["dip"], [.dipStation]),
        (["pull up", "pull-up", "pullup", "chin up", "chin-up", "chinup"], [.pullupBar]),
        (["squat rack", "power rack", "power cage", "squat cage", "barbell", "olympic bar", "bar and plates", "deadlift platform"], [.barbell]),
        (["dumbbell", "dumbell", "db rack"], [.dumbbell]),
        (["kettlebell", "kettle bell"], [.kettlebell]),
        (["bench"], [.bench]),
        (["band"], [.bands]),
        (["triceps", "tricep"], [.cable]),
    ]

    private static let cardioWords = ["bike", "cycle", "rower", "rowing machine", "stair", "step mill",
                                      "stepper", "ski erg", "skierg", "assault", "airdyne", "spin"]

    static func split(_ text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",;\n•·|")
        return text.components(separatedBy: separators)
            .flatMap { $0.components(separatedBy: " and ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "-*•0123456789."))) }
            .filter { !$0.isEmpty }
    }

    static func parse(_ text: String, custom: [String: String] = [:]) -> Result {
        var result = Result()
        var seen = Set<String>()
        for item in split(text) {
            let key = item.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            if let raw = custom[key], let eq = Equipment(rawValue: raw) {
                result.recognized.append(Match(text: item, equipment: [eq]))
                continue
            }
            let cardioMachine = ["tread", "ellip", "cross trainer", "cross-trainer", "crosstrainer", "arc trainer", "running machine"].contains { key.contains($0) }
            if !cardioMachine && cardioWords.contains(where: { key.contains($0) }) && !key.contains("row machine") && !key.contains("seated row") {
                result.cardio.append(item)
                continue
            }
            if let rule = rules.first(where: { rule in rule.0.contains { key.contains($0) } }) {
                result.recognized.append(Match(text: item, equipment: rule.1))
            } else {
                result.unknown.append(item)
            }
        }
        return result
    }

    /// Exercises unlocked by these items, beyond bodyweight.
    static func exercises(for equipment: Set<Equipment>) -> [Exercise] {
        ExerciseLibrary.available(with: equipment).filter { !$0.equipment.allSatisfy { $0 == .bodyweight } }
    }
}
