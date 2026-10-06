import Foundation

/// Supersets and circuits: neighbouring exercises that share a `groupID` are done back to back,
/// one set of each, with the rest only after the last exercise of the round.
extension Workout {
    /// Indices of the exercises in the same group as `index` (just `[index]` when it isn't grouped).
    func groupIndices(of index: Int) -> [Int] {
        guard exercises.indices.contains(index), let g = exercises[index].groupID else { return [index] }
        var lo = index, hi = index
        while lo > 0, exercises[lo - 1].groupID == g { lo -= 1 }
        while hi < exercises.count - 1, exercises[hi + 1].groupID == g { hi += 1 }
        return Array(lo...hi)
    }

    func isGrouped(_ index: Int) -> Bool { groupIndices(of: index).count > 1 }

    /// "Superset A2" / "Circuit B3", or nil when not grouped.
    func groupLabel(_ index: Int) -> String? {
        let members = groupIndices(of: index)
        guard members.count > 1, let pos = members.firstIndex(of: index) else { return nil }
        var letter = 0
        var i = 0
        while i < members[0] {
            let g = groupIndices(of: i)
            if g.count > 1 { letter += 1 }
            i = g.last! + 1
        }
        let name = members.count == 2 ? "Superset" : "Circuit"
        let scalar = UnicodeScalar(65 + min(letter, 25)).map(String.init) ?? "A"
        return "\(name) \(scalar)\(pos + 1)"
    }

    /// After a set of exercise `index` is logged: which exercise comes next, and whether to rest first.
    /// Ungrouped exercises stay put and rest. In a group, move on to the next exercise of the round
    /// without resting; after the last one, rest and start the next round.
    func afterSet(at index: Int) -> (next: Int?, rest: Bool) {
        let members = groupIndices(of: index)
        let unfinished: (Int) -> Bool = { i in exercises[i].sets.contains { !$0.done } }
        guard members.count > 1, let pos = members.firstIndex(of: index) else {
            return (unfinished(index) ? index : nil, true)
        }
        if let n = members[(pos + 1)...].first(where: unfinished) { return (n, false) }
        if let n = members.first(where: unfinished) { return (n, true) }
        return (nil, true)
    }

    /// Rest after a full round: the longest rest of the group.
    func roundRest(_ index: Int) -> Int {
        groupIndices(of: index).map { exercises[$0].restSeconds }.max() ?? exercises[index].restSeconds
    }

    /// Joins the exercise with the one after it.
    mutating func linkWithNext(_ index: Int) {
        guard exercises.indices.contains(index), index + 1 < exercises.count else { return }
        let g = exercises[index].groupID ?? exercises[index + 1].groupID ?? UUID()
        let old = exercises[index + 1].groupID
        exercises[index].groupID = g
        for i in exercises.indices where i > index && (i == index + 1 || (old != nil && exercises[i].groupID == old)) {
            exercises[i].groupID = g
        }
        normalizeGroups()
    }

    /// Takes the exercise out of its group.
    mutating func unlink(_ index: Int) {
        guard exercises.indices.contains(index), let g = exercises[index].groupID else { return }
        let members = groupIndices(of: index)
        exercises[index].groupID = nil
        // Pulling one out of the middle splits the group in two.
        if let pos = members.firstIndex(of: index), pos > 0, pos < members.count - 1 {
            let newID = UUID()
            for i in members[(pos + 1)...] where exercises[i].groupID == g { exercises[i].groupID = newID }
        }
        normalizeGroups()
    }

    /// Groups must be neighbours and have at least two exercises.
    mutating func normalizeGroups() {
        var i = 0
        while i < exercises.count {
            guard let g = exercises[i].groupID else { i += 1; continue }
            var j = i
            while j + 1 < exercises.count, exercises[j + 1].groupID == g { j += 1 }
            if j == i { exercises[i].groupID = nil }
            // The same ID further down (not touching) becomes its own group.
            for k in (j + 1)..<max(j + 1, exercises.count) where exercises[k].groupID == g { exercises[k].groupID = UUID() }
            i = j + 1
        }
    }
}
