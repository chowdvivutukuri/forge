import SwiftUI

/// The user's own exercises: list, edit, delete.
struct CustomExercisesView: View {
    @EnvironmentObject var store: WorkoutStore
    @State private var editing: Exercise?
    @State private var creating = false

    var body: some View {
        List {
            Section {
                if store.settings.customExercises.isEmpty {
                    Text("Add exercises Forge doesn't have. They're suggested in workouts like the built-in ones and sync to your Watch.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(store.settings.customExercises) { ex in
                    Button { editing = ex } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ex.name).foregroundStyle(.primary)
                            Text((ex.primary.map(\.displayName) + ex.equipment.filter { $0 != .bodyweight }.map(\.displayName))
                                .joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { store.settings.customExercises.remove(atOffsets: $0) }
            }
            Section {
                Button { creating = true } label: { Label("New exercise", systemImage: "plus") }
            }
        }
        .forgeScreen()
        .navigationTitle("My Exercises")
        .sheet(item: $editing) { ex in CustomExerciseEditor(existing: ex) { _ in } }
        .sheet(isPresented: $creating) { CustomExerciseEditor(existing: nil) { _ in } }
    }
}

/// Create or edit a custom exercise. Calls `onSave` with the saved exercise.
struct CustomExerciseEditor: View {
    @EnvironmentObject var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    let existing: Exercise?
    var onSave: (Exercise) -> Void

    @State private var name = ""
    @State private var primary: Set<Muscle> = []
    @State private var secondary: Set<Muscle> = []
    @State private var equipment: Set<Equipment> = [.bodyweight]
    @State private var compound = false
    @State private var notes = ""
    @State private var formLike = ""

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !primary.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Landmine Press", text: $name)
                }
                Section {
                    muscleGrid(selection: $primary, other: $secondary)
                } header: {
                    Text("Main muscles")
                } footer: {
                    Text("Used to fit it into the right workouts and track recovery.")
                }
                Section("Also works (optional)") {
                    muscleGrid(selection: $secondary, other: $primary)
                }
                Section {
                    ForEach([Equipment.bodyweight] + Equipment.selectable.filter { !Equipment.cardioMachines.contains($0) }) { eq in
                        Toggle(eq.displayName, isOn: Binding(
                            get: { equipment.contains(eq) },
                            set: { on in if on { equipment.insert(eq) } else { equipment.remove(eq) } }
                        ))
                    }
                } header: {
                    Text("Equipment needed")
                } footer: {
                    Text("Only Bodyweight, bars, bands or a bench means it's logged as reps with optional added weight.")
                }
                Section {
                    Toggle("Multi-joint (compound) lift", isOn: $compound)
                } footer: {
                    Text("Compound lifts go first in a workout and get a warm-up ramp.")
                }
                Section {
                    Picker("Moves like", selection: $formLike) {
                        Text("None").tag("")
                        ForEach(ExerciseLibrary.builtIn.filter { !$0.isCardio }) { Text($0.name).tag($0.id) }
                    }
                } footer: {
                    Text("Borrow a built-in exercise's animation and form cues.")
                }
                Section("How to do it (optional)") {
                    TextField("Your own cues", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .forgeScreen()
            .navigationTitle(existing == nil ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(!canSave) }
            }
            .onAppear(perform: load)
        }
    }

    private func muscleGrid(selection: Binding<Set<Muscle>>, other: Binding<Set<Muscle>>) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(Muscle.allCases) { m in
                let on = selection.wrappedValue.contains(m)
                Button {
                    if on { selection.wrappedValue.remove(m) } else {
                        selection.wrappedValue.insert(m)
                        other.wrappedValue.remove(m)
                    }
                } label: {
                    Text(m.displayName)
                        .font(.subheadline)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(on ? Theme.accent.opacity(0.25) : Color.secondary.opacity(0.12), in: Capsule())
                        .foregroundStyle(on ? Theme.accent : .primary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }

    private func load() {
        guard let ex = existing, name.isEmpty else { return }
        name = ex.name
        primary = Set(ex.primary)
        secondary = Set(ex.secondary)
        equipment = Set(ex.equipment)
        compound = ex.isCompound
        notes = ex.notes ?? ""
        formLike = ex.formLike ?? ""
    }

    private func save() {
        let order = Muscle.allCases
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let ex = Exercise(
            id: existing?.id ?? "custom_" + UUID().uuidString.prefix(8).lowercased(),
            name: name.trimmingCharacters(in: .whitespaces),
            primary: order.filter { primary.contains($0) },
            secondary: order.filter { secondary.contains($0) && !primary.contains($0) },
            equipment: equipment.isEmpty ? [.bodyweight] : Equipment.allCases.filter { equipment.contains($0) },
            isCompound: compound,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            formLike: formLike.isEmpty ? nil : formLike
        )
        if let i = store.settings.customExercises.firstIndex(where: { $0.id == ex.id }) {
            store.settings.customExercises[i] = ex
        } else {
            store.settings.customExercises.append(ex)
        }
        onSave(ex)
        dismiss()
    }
}
