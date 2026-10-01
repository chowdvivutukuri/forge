import SwiftUI
import WatchKit

/// Log one exercise: Digital Crown adjusts weight or reps, tap to switch, then Log Set.
struct WatchExerciseView: View {
    @EnvironmentObject var store: WatchStore
    let itemID: UUID

    enum Field { case weight, reps }

    @State private var weight: Double = 0
    @State private var reps: Double = 0
    @State private var editing: Field = .reps
    @State private var restEnd: Date?

    private var item: WorkoutExercise? { store.workout?.exercises.first { $0.id == itemID } }
    private var nextSet: LoggedSet? { item?.sets.first { !$0.done } }
    private var isBodyweight: Bool { item?.exercise?.isBodyweight ?? false }

    private var crown: Binding<Double> {
        Binding(
            get: { editing == .weight ? weight : reps },
            set: { value in
                if editing == .weight { weight = max(0, value) } else { reps = max(0, value.rounded()) }
            }
        )
    }

    var body: some View {
        if let item {
            VStack(spacing: 6) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)

                if let restEnd, restEnd > Date() {
                    restView(restEnd)
                } else if let next = nextSet {
                    let number = (item.sets.firstIndex { $0.id == next.id } ?? 0) + 1
                    Text("Set \(number) of \(item.sets.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        valueBox(isBodyweight ? "+\(store.unit)" : store.unit,
                                 weight.formatted(.number.precision(.fractionLength(0...1))), .weight)
                        valueBox("reps", "\(Int(reps))", .reps)
                    }
                    Button {
                        store.logSet(itemID: itemID, setID: next.id, reps: Int(reps), weight: weight)
                        WKInterfaceDevice.current().play(.success)
                        if item.sets.filter({ !$0.done }).count > 1 {
                            restEnd = Date().addingTimeInterval(TimeInterval(item.restSeconds))
                        }
                    } label: {
                        Text("Log Set").bold().frame(maxWidth: .infinity)
                    }
                    .tint(.green)
                } else {
                    Label("All sets done", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    HStack {
                        Button("Add Set") { store.addSet(itemID: itemID) }
                        Button("Undo") { store.undoLastSet(itemID: itemID) }
                    }
                    .font(.footnote)
                }
            }
            .focusable()
            .digitalCrownRotation(crown,
                                  from: 0,
                                  through: editing == .weight ? 1500 : 100,
                                  by: editing == .weight ? store.weightStep : 1,
                                  sensitivity: .medium,
                                  isContinuous: false,
                                  isHapticFeedbackEnabled: true)
            .onAppear { load() }
            .onChange(of: nextSet?.id) { _, _ in load() }
        }
    }

    private func load() {
        guard let s = nextSet else { return }
        weight = s.weight
        reps = Double(s.reps)
        editing = (isBodyweight && s.weight == 0) ? .reps : editing
    }

    private func valueBox(_ label: String, _ value: String, _ field: Field) -> some View {
        Button {
            editing = field
        } label: {
            VStack(spacing: 0) {
                Text(value).font(.title3.monospacedDigit().bold())
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(editing == field ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func restView(_ end: Date) -> some View {
        VStack(spacing: 6) {
            Text("Rest").font(.caption).foregroundStyle(.secondary)
            Text(timerInterval: Date()...max(Date(), end), countsDown: true)
                .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
            Button("Skip") { restEnd = nil }
                .font(.footnote)
        }
        .task(id: end) {
            let wait = end.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            if !Task.isCancelled {
                WKInterfaceDevice.current().play(.notification)
                restEnd = nil
            }
        }
    }
}
