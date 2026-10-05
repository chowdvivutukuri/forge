import Foundation

/// Which plates to load on each side of the bar.
enum Plates {
    static let pounds: [Double] = [45, 35, 25, 10, 5, 2.5]
    static let kilograms: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    /// Lifts loaded with plates on a bar.
    static func usesPlates(_ ex: Exercise) -> Bool {
        ex.equipment.contains(.barbell) || ex.equipment.contains(.smith)
    }

    /// Empty bar: Olympic barbell 45 lb / 20 kg. A Smith bar is counterbalanced, so it counts lighter.
    static func barWeight(for ex: Exercise, kg: Bool) -> Double {
        if ex.equipment.contains(.barbell) { return kg ? 20 : 45 }
        if ex.equipment.contains(.smith) { return kg ? 10 : 20 }
        return 0
    }

    /// Plates for one side, heaviest first, and any weight that can't be made with the plate set.
    static func perSide(total: Double, bar: Double, kg: Bool) -> (plates: [Double], leftover: Double) {
        var side = max(0, (total - bar) / 2)
        var plates: [Double] = []
        for p in kg ? kilograms : pounds {
            while side >= p - 0.001 {
                plates.append(p)
                side -= p
            }
        }
        return (plates, side < 0.01 ? 0 : side * 2)
    }

    /// "Each side: 45 + 25 + 5", or "Empty bar". Nil for lifts that don't use plates.
    static func summary(total: Double, for ex: Exercise, kg: Bool) -> String? {
        guard usesPlates(ex), total > 0 else { return nil }
        let bar = barWeight(for: ex, kg: kg)
        if total < bar - 0.01 { return "Below the \(fmt(bar)) \(kg ? "kg" : "lb") bar" }
        let r = perSide(total: total, bar: bar, kg: kg)
        if r.plates.isEmpty && r.leftover == 0 { return "Empty bar" }
        var text = "Each side: " + (r.plates.isEmpty ? "nothing" : compact(r.plates))
        if r.leftover > 0 { text += " (+\(fmt(r.leftover)) not possible)" }
        return text
    }

    /// Groups repeats: [45, 45, 10] → "2×45 + 10".
    static func compact(_ plates: [Double]) -> String {
        var parts: [String] = []
        var i = 0
        while i < plates.count {
            var n = 1
            while i + n < plates.count && plates[i + n] == plates[i] { n += 1 }
            parts.append(n > 1 ? "\(n)×\(fmt(plates[i]))" : fmt(plates[i]))
            i += n
        }
        return parts.joined(separator: " + ")
    }

    static func fmt(_ w: Double) -> String { w.formatted(.number.precision(.fractionLength(0...2))) }
}

/// Warm-up ramp before the working sets: lighter sets with fewer reps as the weight climbs.
/// Warm-ups are shown as a guide and never logged, so they don't count toward volume, progression or recovery.
struct WarmupSet: Hashable, Sendable {
    var weight: Double
    var reps: Int
}

enum Warmup {
    static func sets(working: Double, for ex: Exercise, kg: Bool) -> [WarmupSet] {
        guard !ex.isBodyweight, ex.isCompound, !ex.isCardio, working > 0 else { return [] }
        let platesLift = Plates.usesPlates(ex)
        let bar = Plates.barWeight(for: ex, kg: kg)
        let step: Double
        if ex.equipment.contains(.dumbbell) { step = kg ? 2 : 5 }
        else if platesLift { step = kg ? 5 : 10 }   // smallest jump with a pair of plates
        else { step = kg ? 2.5 : 5 }
        let floor = platesLift ? bar : step
        // Too light to need a ramp.
        guard working >= floor + 2 * step else { return [] }

        var ramp: [WarmupSet] = platesLift ? [WarmupSet(weight: bar, reps: 10)] : []
        for (pct, reps) in [(0.4, 8), (0.6, 5), (0.8, 3)] {
            let w = max(floor, (working * pct / step).rounded() * step)
            guard w < working - 0.01 else { continue }
            if let last = ramp.last, w <= last.weight + 0.01 { continue }
            ramp.append(WarmupSet(weight: w, reps: reps))
        }
        return ramp
    }
}
