import SwiftUI

struct ExerciseCard: View {
    @Binding var item: WorkoutExercise
    let unit: String
    var onSetCompleted: (Int) -> Void
    var onSwap: () -> Void
    var onChoose: () -> Void
    var onRemove: () -> Void
    var onExclude: () -> Void

    private var isBodyweight: Bool { item.exercise?.isBodyweight ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name).font(.headline)
                    if let ex = item.exercise {
                        Text(ex.primary.map(\.displayName).joined(separator: ", "))
                            .font(.caption).foregroundStyle(.secondary)
                        Text(ex.equipment.filter { $0 != .bodyweight }.map(\.displayName).joined(separator: " + "))
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Menu {
                    Button("Swap for similar", systemImage: "arrow.triangle.2.circlepath", action: onSwap)
                    Button("Choose exercise…", systemImage: "list.bullet", action: onChoose)
                    Button("Never suggest this", systemImage: "hand.thumbsdown", action: onExclude)
                    Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }

            HStack {
                Text("SET").frame(width: 34, alignment: .leading)
                Text(isBodyweight ? "+\(unit)" : unit.uppercased()).frame(maxWidth: .infinity)
                Text("REPS").frame(maxWidth: .infinity)
                Spacer().frame(width: 40)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)

            ForEach($item.sets) { $set in
                let index = (item.sets.firstIndex { $0.id == set.id } ?? 0) + 1
                HStack {
                    Text("\(index)")
                        .font(.subheadline.monospacedDigit())
                        .frame(width: 34, alignment: .leading)
                    TextField("0", value: $set.weight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    TextField("0", value: $set.reps, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    Button {
                        set.done.toggle()
                        if set.done { onSetCompleted(item.restSeconds) }
                    } label: {
                        Image(systemName: set.done ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(set.done ? Color.green : Color.secondary)
                    }
                    .buttonStyle(.borderless)
                    .frame(width: 40)
                }
                .opacity(set.done ? 0.75 : 1)
            }

            HStack {
                Button {
                    let last = item.sets.last ?? LoggedSet(reps: 10, weight: 0)
                    item.sets.append(LoggedSet(reps: last.reps, weight: last.weight))
                } label: { Label("Add Set", systemImage: "plus.circle") }
                .buttonStyle(.borderless)
                if item.sets.count > 1 {
                    Button(role: .destructive) {
                        item.sets.removeLast()
                    } label: { Label("Remove", systemImage: "minus.circle") }
                    .buttonStyle(.borderless)
                }
                Spacer()
                Label("\(item.restSeconds)s rest", systemImage: "timer")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

struct ExercisePickerView: View {
    @EnvironmentObject var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var showAll = false
    let onPick: (Exercise) -> Void

    private var exercises: [Exercise] {
        let base = showAll ? ExerciseLibrary.all : store.generator.availableExercises
        guard !search.isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(search) ||
            $0.primary.contains { $0.displayName.localizedCaseInsensitiveContains(search) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Toggle("Include exercises needing other equipment", isOn: $showAll)
                    .font(.subheadline)
                ForEach(Muscle.allCases) { muscle in
                    let group = exercises.filter { $0.primary.first == muscle }
                    if !group.isEmpty {
                        Section(muscle.displayName) {
                            ForEach(group) { ex in
                                Button {
                                    onPick(ex)
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ex.name).foregroundStyle(.primary)
                                        Text(ex.equipment.map(\.displayName).joined(separator: " + "))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search exercises or muscles")
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
