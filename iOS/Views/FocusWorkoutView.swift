import SwiftUI
import UIKit

/// One exercise and its current set at a time. "Overview" shows the full list.
struct FocusWorkoutView: View {
    @EnvironmentObject var store: WorkoutStore
    @Binding var workout: Workout
    @Binding var index: Int
    var onSetCompleted: (Int) -> Void
    var onShowForm: (String) -> Void
    var onOverview: () -> Void
    var onFinish: () -> Void
    var onSwap: (UUID) -> Void

    @State private var editingWeight = false
    @State private var editingReps = false
    @FocusState private var fieldFocused: Bool

    private var exercises: [WorkoutExercise] { workout.exercises }
    private var safeIndex: Int { min(max(0, index), max(0, exercises.count - 1)) }
    private var allDone: Bool { exercises.allSatisfy { $0.sets.allSatisfy(\.done) } }

    var body: some View {
        if exercises.isEmpty {
            ContentUnavailableView("No exercises", systemImage: "dumbbell",
                                   description: Text("Add an exercise from the overview."))
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    progressStrip
                    exerciseHeader
                    if exercises[safeIndex].isCardio {
                        ExerciseCard(
                            item: $workout.exercises[safeIndex],
                            unit: store.settings.weightUnit,
                            settings: store.settings,
                            bodyKg: store.latestWeightKg ?? 75,
                            onSetCompleted: { _ in advanceIfComplete() },
                            onShowForm: { onShowForm(exercises[safeIndex].exerciseID) },
                            onSwap: { onSwap(exercises[safeIndex].id) },
                            onChoose: onOverview,
                            onRemove: onOverview,
                            onExclude: onOverview
                        )
                        .padding()
                        .background(card)
                        nextButtons
                    } else if let setIndex = currentSetIndex {
                        setCard(setIndex)
                    } else {
                        exerciseComplete
                    }
                    if allDone {
                        Button(action: onFinish) {
                            Label("Finish workout", systemImage: "checkmark.seal.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button(action: onOverview) {
                        Label("See all exercises", systemImage: "list.bullet")
                    }
                    .font(.subheadline)
                    .padding(.top, 4)
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear { if index >= exercises.count { index = 0 } }
        }
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemGroupedBackground))
    }

    // MARK: Header

    private var progressStrip: some View {
        HStack(spacing: 4) {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { i, item in
                let done = item.sets.allSatisfy(\.done)
                Capsule()
                    .fill(i == safeIndex ? Theme.accent : (done ? ForgeColors.positive.opacity(0.7) : Color.secondary.opacity(0.25)))
                    .frame(height: 5)
                    .onTapGesture { withAnimation { index = i } }
            }
        }
    }

    private var exerciseHeader: some View {
        let item = exercises[safeIndex]
        return VStack(spacing: 10) {
            HStack {
                Button { withAnimation { index = max(0, safeIndex - 1) } } label: {
                    Image(systemName: "chevron.left").font(.title3.bold()).frame(width: 44, height: 44)
                }
                .disabled(safeIndex == 0)
                Spacer()
                Text("EXERCISE \(safeIndex + 1) OF \(exercises.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button { withAnimation { index = min(exercises.count - 1, safeIndex + 1) } } label: {
                    Image(systemName: "chevron.right").font(.title3.bold()).frame(width: 44, height: 44)
                }
                .disabled(safeIndex >= exercises.count - 1)
            }
            Button { onShowForm(item.exerciseID) } label: {
                FormFigureView(exerciseID: item.exerciseID)
                    .frame(height: 190)
                    .frame(maxWidth: .infinity)
                    .background(card)
                    .overlay(alignment: .bottomTrailing) {
                        Label("Form", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.caption2.weight(.semibold))
                            .padding(8)
                    }
            }
            .buttonStyle(.plain)
            Text(item.name).font(.title2.bold()).multilineTextAlignment(.center)
            if let ex = item.exercise {
                Text(ex.primary.map(\.displayName).joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Current set

    private var currentSetIndex: Int? {
        exercises[safeIndex].sets.firstIndex { !$0.done }
    }

    private var isBodyweight: Bool { exercises[safeIndex].exercise?.isBodyweight ?? false }

    private var weightStep: Double {
        guard let ex = exercises[safeIndex].exercise else { return store.settings.weightStep }
        return store.generator.step(for: ex)
    }

    private func setCard(_ s: Int) -> some View {
        let item = exercises[safeIndex]
        let set = item.sets[s]
        let kg = store.settings.useKilograms
        let unit = store.settings.weightUnit
        return VStack(spacing: 18) {
            if s == 0, let ex = item.exercise {
                let ramp = Warmup.sets(working: set.weight, for: ex, kg: kg)
                if !ramp.isEmpty {
                    WarmupPanel(ramp: ramp, exercise: ex, unit: unit, kg: kg)
                        .id("\(item.id)-warmup")
                }
            }
            Text("SET \(s + 1) OF \(item.sets.count)")
                .font(.headline)
                .foregroundStyle(Theme.accent)

            HStack(spacing: 14) {
                valueControl(
                    title: isBodyweight ? "ADDED \(store.settings.weightUnit.uppercased())" : store.settings.weightUnit.uppercased(),
                    text: Theme.formatWeight(set.weight),
                    minus: { setWeight(s, max(0, set.weight - weightStep)) },
                    plus: { setWeight(s, set.weight + weightStep) },
                    editing: $editingWeight,
                    field: AnyView(TextField("0", value: Binding(get: { set.weight }, set: { setWeight(s, $0) }), format: .number)
                        .keyboardType(.decimalPad))
                )
                valueControl(
                    title: "REPS",
                    text: "\(set.reps)",
                    minus: { workout.exercises[safeIndex].sets[s].reps = max(0, set.reps - 1) },
                    plus: { workout.exercises[safeIndex].sets[s].reps = set.reps + 1 },
                    editing: $editingReps,
                    field: AnyView(TextField("0", value: Binding(get: { set.reps }, set: { workout.exercises[safeIndex].sets[s].reps = $0 }), format: .number)
                        .keyboardType(.numberPad))
                )
            }

            if let ex = item.exercise, let plates = Plates.summary(total: set.weight, for: ex, kg: kg) {
                Label(plates, systemImage: "circle.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                editingWeight = false
                editingReps = false
                fieldFocused = false
                workout.exercises[safeIndex].sets[s].done = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let lastOfExercise = workout.exercises[safeIndex].sets.allSatisfy(\.done)
                if !(lastOfExercise && safeIndex == exercises.count - 1) {
                    onSetCompleted(item.restSeconds)
                }
                if lastOfExercise { advanceIfComplete() }
            } label: {
                Label("Done — set \(s + 1)", systemImage: "checkmark")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)

            if s > 0 {
                let prev = item.sets[s - 1]
                Text("Last set: \(prev.weight > 0 ? "\(Theme.formatWeight(prev.weight)) \(store.settings.weightUnit) × " : "")\(prev.reps)")
                    .font(.caption).foregroundStyle(.secondary)
            } else if let target = item.targetReps, let suggested = item.suggestedWeight, suggested > 0 {
                Text("Plan: \(item.sets.count) × \(target) at \(Theme.formatWeight(suggested)) \(store.settings.weightUnit)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Add a set") {
                    workout.exercises[safeIndex].sets.append(LoggedSet(reps: set.reps, weight: set.weight))
                }
                Spacer()
                Button("Swap exercise") { onSwap(item.id) }
                Spacer()
                Button("Skip") { withAnimation { index = min(exercises.count - 1, safeIndex + 1) } }
                    .disabled(safeIndex >= exercises.count - 1)
            }
            .font(.footnote)
        }
        .padding()
        .background(card)
    }

    private func valueControl(title: String, text: String, minus: @escaping () -> Void, plus: @escaping () -> Void,
                              editing: Binding<Bool>, field: AnyView) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            if editing.wrappedValue {
                field
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .focused($fieldFocused)
                    .onAppear { fieldFocused = true }
            } else {
                Text(text)
                    .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                    .onTapGesture { editing.wrappedValue = true }
            }
            HStack(spacing: 12) {
                Button(action: minus) { Image(systemName: "minus").frame(width: 44, height: 36) }
                Button(action: plus) { Image(systemName: "plus").frame(width: 44, height: 36) }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
    }

    /// Changing the weight also updates later sets that haven't been done yet.
    private func setWeight(_ s: Int, _ value: Double) {
        let old = workout.exercises[safeIndex].sets[s].weight
        workout.exercises[safeIndex].sets[s].weight = value
        for j in workout.exercises[safeIndex].sets.indices where j > s && !workout.exercises[safeIndex].sets[j].done
            && workout.exercises[safeIndex].sets[j].weight == old {
            workout.exercises[safeIndex].sets[j].weight = value
        }
    }

    // MARK: Between exercises

    private var exerciseComplete: some View {
        VStack(spacing: 12) {
            Label("\(exercises[safeIndex].name) done", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(ForgeColors.positive)
            nextButtons
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(card)
    }

    @ViewBuilder private var nextButtons: some View {
        if let next = nextUnfinished {
            Button {
                withAnimation { index = next }
            } label: {
                Label("Next: \(exercises[next].name)", systemImage: "arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var nextUnfinished: Int? {
        let order = Array(safeIndex + 1..<exercises.count) + Array(0..<safeIndex)
        return order.first { !exercises[$0].sets.allSatisfy(\.done) }
    }

    private func advanceIfComplete() {
        guard workout.exercises[safeIndex].sets.allSatisfy(\.done), let next = nextUnfinished else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation { index = next }
        }
    }
}
