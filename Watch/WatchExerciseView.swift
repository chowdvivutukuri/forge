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
    @State private var showForm = false

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
        if let item, item.isCardio {
            WatchCardioView(itemID: itemID)
        } else if let item {
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
                    .tint(ForgeColors.positive)
                } else {
                    Label("All sets done", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(ForgeColors.positive)
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
            .watchAbhi()
            .onAppear { load() }
            .onChange(of: nextSet?.id) { _, _ in load() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showForm = true
                    } label: {
                        Image(systemName: "figure.strengthtraining.traditional")
                    }
                    .accessibilityLabel("Show form")
                }
            }
            .sheet(isPresented: $showForm) { WatchFormView(exerciseID: item.exerciseID) }
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

/// Animated form guide on the watch. Tap the figure to switch between side and front.
struct WatchFormView: View {
    let exerciseID: String
    @State private var angle: FormAngle = .side

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                FormFigureView(exerciseID: exerciseID, yaw: angle.yaw, spin: angle == .turn,
                               palette: FormPalette(ink: .white, accent: ForgeColors.accent, face: .black))
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .onTapGesture {
                        let all = FormAngle.allCases
                        angle = all[((all.firstIndex(of: angle) ?? 0) + 1) % all.count]
                    }
                Text("\(angle.label) view · tap to change")
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                ForEach(Array(FormLibrary.cues(for: exerciseID).enumerated()), id: \.offset) { i, cue in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(i + 1)").font(.caption.bold()).foregroundStyle(ForgeColors.accent)
                        Text(cue).font(.caption)
                    }
                }
            }
        }
        .watchAbhi()
        .navigationTitle(ExerciseLibrary.byID[exerciseID]?.name ?? "Form")
        .onAppear { angle = FormLibrary.defaultYaw(for: exerciseID) == 0 ? .front : .side }
    }
}

/// Treadmill / elliptical on the watch: shows the plan, times the session, logs the minutes.
struct WatchCardioView: View {
    @EnvironmentObject var store: WatchStore
    let itemID: UUID
    @State private var started: Date?
    @State private var minutes: Double = 0
    @State private var showForm = false

    private var item: WorkoutExercise? { store.workout?.exercises.first { $0.id == itemID } }

    var body: some View {
        if let item {
            ScrollView {
                VStack(spacing: 6) {
                    Text(item.name).font(.headline).multilineTextAlignment(.center)
                    Text(Cardio.summary(item, settings: store.unitSettings))
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    if let note = item.note {
                        Text(note).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    if item.sets.first?.done == true {
                        Label("Logged \(Cardio.fmt(item.cardioMinutes)) min", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(ForgeColors.positive)
                    } else if let started {
                        Text(timerInterval: started...Date.distantFuture, countsDown: false)
                            .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                        Button("Done") {
                            let elapsed = max(1, (Date().timeIntervalSince(started) / 60).rounded())
                            store.logCardio(itemID: itemID, minutes: elapsed)
                            WKInterfaceDevice.current().play(.success)
                        }
                        .tint(ForgeColors.positive)
                    } else {
                        Text("\(Cardio.fmt(minutes)) min").font(.title2.monospacedDigit().bold())
                            .focusable()
                            .digitalCrownRotation($minutes, from: 1, through: 120, by: 1, sensitivity: .medium,
                                                  isContinuous: false, isHapticFeedbackEnabled: true)
                        Button("Start timer") { started = Date() }
                            .tint(ForgeColors.accent)
                        Button("Log \(Cardio.fmt(minutes)) min") {
                            store.logCardio(itemID: itemID, minutes: minutes)
                            WKInterfaceDevice.current().play(.success)
                        }
                        .font(.footnote)
                    }
                }
            }
            .watchAbhi()
            .onAppear { minutes = item.sets.first?.minutes ?? item.targetMinutes ?? 20 }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showForm = true } label: { Image(systemName: "figure.run") }
                }
            }
            .sheet(isPresented: $showForm) { WatchFormView(exerciseID: item.exerciseID) }
        }
    }
}
