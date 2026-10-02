import SwiftUI

struct ExerciseCard: View {
    @Binding var item: WorkoutExercise
    let unit: String
    var settings = UserSettings()
    var bodyKg: Double = 75
    var onSetCompleted: (Int) -> Void
    var onShowForm: () -> Void
    var onSwap: () -> Void
    var onChoose: () -> Void
    var onRemove: () -> Void
    var onExclude: () -> Void

    private var isBodyweight: Bool { item.exercise?.isBodyweight ?? false }

    /// Changing a set's weight also updates later sets that haven't been done yet.
    private func weightBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: { item.sets.indices.contains(index) ? item.sets[index].weight : 0 },
            set: { newValue in
                guard item.sets.indices.contains(index) else { return }
                let old = item.sets[index].weight
                item.sets[index].weight = newValue
                for j in item.sets.indices where j > index && !item.sets[j].done && item.sets[j].weight == old {
                    item.sets[j].weight = newValue
                }
            }
        )
    }

    private func repsBinding(_ index: Int) -> Binding<Int> {
        Binding(
            get: { item.sets.indices.contains(index) ? item.sets[index].reps : 0 },
            set: { if item.sets.indices.contains(index) { item.sets[index].reps = $0 } }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Button(action: onShowForm) {
                    FormFigureView(exerciseID: item.exerciseID)
                        .frame(width: 58, height: 58)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Show form for \(item.name)")

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name).font(.headline)
                    if let ex = item.exercise {
                        Text(ex.primary.map(\.displayName).joined(separator: ", "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button("How to do it", action: onShowForm)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderless)
                }
                Spacer()
                Menu {
                    Button("How to do it", systemImage: "figure.strengthtraining.traditional", action: onShowForm)
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

            if item.isCardio {
                cardioBody
            } else {
                strengthBody
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Cardio

    private func cardioValue(_ key: WritableKeyPath<LoggedSet, Double?>) -> Binding<Double> {
        Binding(
            get: { item.sets.first?[keyPath: key] ?? 0 },
            set: { v in
                if item.sets.isEmpty { item.sets.append(LoggedSet(reps: 0, weight: 0)) }
                item.sets[0][keyPath: key] = v
            }
        )
    }

    @ViewBuilder private var cardioBody: some View {
        let treadmill = Cardio.isTreadmill(item.exerciseID)
        let done = item.sets.first?.done ?? false
        if let note = item.note {
            Label(note, systemImage: "repeat")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        HStack(spacing: 8) {
            cardioField("MIN", cardioValue(\.minutes))
            cardioField(treadmill ? settings.speedUnit.uppercased() : "LEVEL", cardioValue(\.speed))
            if treadmill { cardioField("INCLINE %", cardioValue(\.incline)) }
            Button {
                if item.sets.isEmpty { item.sets.append(LoggedSet(reps: 0, weight: 0)) }
                item.sets[0].done.toggle()
                if item.sets[0].done {
                    let s = item.sets[0]
                    item.sets[0].distance = Cardio.distance(item.exerciseID, minutes: s.minutes ?? 0, speed: s.speed)
                }
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(done ? ForgeColors.positive : Color.secondary)
            }
            .buttonStyle(.borderless)
            .frame(width: 40)
        }
        if let s = item.sets.first {
            let kcal = Cardio.calories(item.exerciseID, minutes: s.minutes ?? 0, speed: s.speed, incline: s.incline,
                                       bodyKg: bodyKg, useKm: settings.useKilograms)
            HStack {
                Label("≈ \(Int(kcal.rounded())) kcal", systemImage: "flame")
                if let d = Cardio.distance(item.exerciseID, minutes: s.minutes ?? 0, speed: s.speed) {
                    Label("\(Cardio.fmt(d)) \(settings.distanceUnit)", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                }
                Spacer()
                if let target = item.targetMinutes, let m = s.minutes, abs(m - target) >= 0.5 {
                    Text("Suggested \(Cardio.fmt(target)) min").foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Text("Log what you actually did — next time's suggestion builds on it.")
            .font(.caption2).foregroundStyle(.secondary)
    }

    private func cardioField(_ label: String, _ value: Binding<Double>) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: Strength

    @ViewBuilder private var strengthBody: some View {
            HStack {
                Text("SET").frame(width: 34, alignment: .leading)
                Text(isBodyweight ? "+\(unit)" : unit.uppercased()).frame(maxWidth: .infinity)
                Text("REPS").frame(maxWidth: .infinity)
                Spacer().frame(width: 40)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)

            ForEach(Array(item.sets.enumerated()), id: \.element.id) { index, set in
                HStack {
                    Text("\(index + 1)")
                        .font(.subheadline.monospacedDigit())
                        .frame(width: 34, alignment: .leading)
                    TextField("0", value: weightBinding(index), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    TextField("0", value: repsBinding(index), format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    Button {
                        item.sets[index].done.toggle()
                        if item.sets[index].done { onSetCompleted(item.restSeconds) }
                    } label: {
                        Image(systemName: set.done ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(set.done ? ForgeColors.positive : Color.secondary)
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

            if let suggested = item.suggestedWeight, suggested > 0, !isBodyweight {
                let used = item.sets.first?.weight ?? suggested
                if abs(used - suggested) >= 0.5 {
                    Text("Suggested \(Theme.formatWeight(suggested)) \(unit). Forge will base your next suggestion on what you log.")
                        .font(.caption2).foregroundStyle(.secondary)
                } else if let reps = item.targetReps {
                    Text("Target: \(item.sets.count) × \(reps). Hit every rep and the weight goes up next time.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
    }
}

struct ExercisePickerView: View {
    @EnvironmentObject var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var showAll = false
    @State private var info: FormSheetID?
    let onPick: (Exercise) -> Void

    private var exercises: [Exercise] {
        let base = showAll ? ExerciseLibrary.all : store.generator.availableExercises
        guard !search.isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(search) ||
            $0.primary.contains { $0.displayName.localizedCaseInsensitiveContains(search) } ||
            $0.equipment.contains { $0.displayName.localizedCaseInsensitiveContains(search) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Toggle("Include exercises needing other equipment", isOn: $showAll)
                    .font(.subheadline)
                ForEach(MuscleGroup.allCases) { group in
                    let items = exercises.filter { $0.group == group }
                    if !items.isEmpty {
                        Section(group.displayName) {
                            ForEach(items) { ex in
                                HStack(spacing: 10) {
                                    FormFigureView(exerciseID: ex.id)
                                        .frame(width: 44, height: 44)
                                    Button {
                                        onPick(ex)
                                        dismiss()
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(ex.name).foregroundStyle(.primary)
                                            Text(ex.equipment.map(\.displayName).joined(separator: " + "))
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.borderless)
                                    Button {
                                        info = FormSheetID(id: ex.id)
                                    } label: {
                                        Image(systemName: "info.circle")
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search exercises, muscles, machines")
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .sheet(item: $info) { FormDetailView(exerciseID: $0.id) }
        }
    }
}
