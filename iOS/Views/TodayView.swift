import SwiftUI
import UIKit

struct TodayView: View {
    @EnvironmentObject var store: WorkoutStore
    @State private var pickerTarget: PickerTarget?
    @State private var formExercise: String?
    @State private var confirmFinish = false
    @State private var confirmDiscard = false
    @State private var finishing = false
    @State private var restEnd: Date?
    @AppStorage("forge.focusMode") private var focusMode = true
    @State private var focusIndex = 0

    var body: some View {
        NavigationStack {
            Group {
                if store.current == nil {
                    emptyState
                } else if focusMode {
                    FocusWorkoutView(
                        workout: workoutBinding,
                        index: $focusIndex,
                        onSetCompleted: { rest in restEnd = Date().addingTimeInterval(TimeInterval(rest)) },
                        onShowForm: { formExercise = $0 },
                        onOverview: { withAnimation { focusMode = false } },
                        onFinish: { confirmFinish = true },
                        onSwap: { store.swap(itemID: $0) }
                    )
                } else {
                    activeWorkout
                }
            }
            .onChange(of: store.current?.id) { _, _ in focusIndex = firstUnfinishedIndex }
            .forgeScreen()
            .navigationTitle(store.current?.title ?? "Today")
            .toolbar {
                if store.current != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation {
                                if !focusMode { focusIndex = firstUnfinishedIndex }
                                focusMode.toggle()
                            }
                        } label: {
                            Label(focusMode ? "Overview" : "Focus", systemImage: focusMode ? "list.bullet" : "scope")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Regenerate Workout", systemImage: "arrow.clockwise") { regenerate() }
                            Button("Discard Workout", systemImage: "trash", role: .destructive) { confirmDiscard = true }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .sheet(item: $pickerTarget) { target in
                ExercisePickerView { exercise in
                    switch target {
                    case .add: store.addExercise(exercise)
                    case .replace(let id): store.replace(itemID: id, with: exercise)
                    }
                }
            }
            .sheet(item: Binding(get: { formExercise.map { FormSheetID(id: $0) } }, set: { formExercise = $0?.id })) { item in
                FormDetailView(exerciseID: item.id)
            }
            .confirmationDialog("Finish this workout?", isPresented: $confirmFinish, titleVisibility: .visible) {
                Button("Finish & Save") {
                    finishing = true
                    Task {
                        await store.finishCurrent()
                        finishing = false
                        restEnd = nil
                    }
                }
            } message: {
                Text("Completed sets are saved to Progress\(store.settings.healthEnabled ? " and Apple Health" : ""). Your next suggestions adjust to what you lifted.")
            }
            .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { store.discardCurrent(); restEnd = nil }
            }
            .onChange(of: restEnd) { _, end in store.setRestEnd(end) }
            .safeAreaInset(edge: .bottom) {
                if let restEnd, restEnd > Date() {
                    RestBanner(end: restEnd) { self.restEnd = nil }
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                }
            }
        }
    }

    private var firstUnfinishedIndex: Int {
        store.current?.exercises.firstIndex { !$0.sets.allSatisfy(\.done) } ?? 0
    }

    private func regenerate() {
        guard let w = store.current else { return }
        if let day = w.programDay { store.startProgramDay(day) } else { store.startNextProgramDay() }
    }

    // MARK: Empty state

    private var emptyState: some View {
        let schedule = store.settings.schedule
        let day = store.programDayIndex
        let focus = schedule.isEmpty ? SplitFocus.fullBody : schedule[day]
        return List {
            if store.needsWeighIn {
                Section { WeighInCard() }
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("DAY \(day + 1) OF \(schedule.count) · \(store.settings.split.displayName.uppercased())")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(focus.displayName).font(.largeTitle.bold())
                    Text(focus.muscles.prefix(6).map(\.displayName).joined(separator: " · "))
                        .font(.footnote).foregroundStyle(.secondary)
                    Button {
                        store.startNextProgramDay()
                    } label: {
                        Label("Start Day \(day + 1)", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)

                    Menu {
                        Section("Another program day") {
                            ForEach(Array(schedule.enumerated()), id: \.offset) { i, f in
                                Button("Day \(i + 1) · \(f.displayName)") { store.startPlannedDay(i) }
                            }
                        }
                        Section("One-off workout") {
                            ForEach(SplitFocus.pickable) { f in
                                Button(f.displayName) { store.generateWorkout(focus: f) }
                            }
                        }
                    } label: {
                        Label("Train something else", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 6)
            } footer: {
                Text("Exercises are picked from the “\(store.settings.activeProfile.name)” equipment, favouring muscles that have recovered.")
            }

            Section {
                EquipmentProfileBar()
            } header: {
                Text("Training with")
            }

            Section("Music") { SpotifyCard() }
        }
    }

    // MARK: Active workout

    private var workoutBinding: Binding<Workout> {
        Binding(
            get: { store.current ?? Workout(title: "", exercises: []) },
            set: { store.update($0) }
        )
    }

    private var activeWorkout: some View {
        let workout = workoutBinding
        let calibration = store.generator.calibration
        return List {
            Section {
                HStack {
                    Label(store.current?.equipmentProfileName ?? store.settings.activeProfile.name, systemImage: "dumbbell")
                    Spacer()
                    Text("\(store.current?.completedSetCount ?? 0) sets done")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                SpotifyCard(compact: true)
            } footer: {
                if abs(calibration - 1) > 0.1 {
                    Text("Starting weights for new exercises are scaled to \(Int((calibration * 100).rounded()))% of the standard estimate, based on what you've been lifting.")
                }
            }

            ForEach(workout.exercises) { $item in
                Section {
                    Button {
                        if let i = store.current?.exercises.firstIndex(where: { $0.id == item.id }) { focusIndex = i }
                        withAnimation { focusMode = true }
                    } label: {
                        Label("Do this exercise", systemImage: "scope").font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderless)
                    ExerciseCard(
                        item: $item,
                        unit: store.settings.weightUnit,
                        settings: store.settings,
                        bodyKg: store.latestWeightKg ?? 75,
                        onSetCompleted: { rest in
                            // In a superset, rest only after the last exercise of the round.
                            guard let w = store.current, let i = w.exercises.firstIndex(where: { $0.id == item.id }) else { return }
                            if !w.isGrouped(i) {
                                restEnd = Date().addingTimeInterval(TimeInterval(rest))
                            } else if w.groupIndices(of: i).last == i {
                                restEnd = Date().addingTimeInterval(TimeInterval(w.roundRest(i)))
                            }
                        },
                        onShowForm: { formExercise = item.exerciseID },
                        onSwap: { store.swap(itemID: item.id) },
                        onChoose: { pickerTarget = .replace(item.id) },
                        onRemove: { store.remove(itemID: item.id) },
                        onExclude: {
                            store.excludeExercise(item.exerciseID)
                            store.swap(itemID: item.id)
                        },
                        onPrefer: { store.settings.exercisePreferences[item.exerciseID] = $0 },
                        groupLabel: groupLabel(item.id),
                        onLinkNext: isLast(item.id) ? nil : { store.linkWithNext(itemID: item.id) },
                        onUnlink: { store.unlink(itemID: item.id) }
                    )
                }
            }

            Section {
                Button { pickerTarget = .add } label: { Label("Add Exercise", systemImage: "plus") }
                Button {
                    confirmFinish = true
                } label: {
                    HStack {
                        Spacer()
                        if finishing { ProgressView() } else { Text("Finish Workout").bold() }
                        Spacer()
                    }
                }
                .disabled(finishing)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

struct FormSheetID: Identifiable {
    let id: String
}

enum PickerTarget: Identifiable {
    case add
    case replace(UUID)
    var id: String {
        switch self {
        case .add: return "add"
        case .replace(let id): return id.uuidString
        }
    }
}

// MARK: - Weigh-in

struct WeighInCard: View {
    @EnvironmentObject var store: WorkoutStore
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(store.weighIns.isEmpty ? "Log your weight" : "Weekly weigh-in", systemImage: "scalemass")
                .font(.headline)
            Text(store.weighIns.isEmpty
                 ? "Used for starting weights and to track your progress."
                 : "It's been over a week. Weigh in at the same time of day for the clearest trend.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField(store.latestWeightKg.map { Theme.formatWeight(store.settings.displayWeight(kg: $0)) } ?? "Weight", text: $text)
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .padding(8)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                Text(store.settings.weightUnit).foregroundStyle(.secondary)
                Button("Save") {
                    if let v = Double(text.replacingOccurrences(of: ",", with: ".")) {
                        store.logWeight(displayValue: v)
                        text = ""
                        focused = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(Double(text.replacingOccurrences(of: ",", with: ".")) == nil)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Equipment profile switcher

struct EquipmentProfileBar: View {
    @EnvironmentObject var store: WorkoutStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(store.settings.profiles) { profile in
                        let active = profile.id == store.settings.activeProfile.id
                        Button {
                            store.setActiveProfile(profile.id)
                        } label: {
                            Text(profile.name)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(active ? Theme.accent : Color.secondary.opacity(0.15), in: Capsule())
                                .foregroundStyle(active ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            let gear = Equipment.selectable.filter { $0.isCovered(by: store.settings.activeProfile.equipment) }
            Text(gear.isEmpty ? "Bodyweight only" : gear.map(\.displayName).joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Text("\(store.generator.availableExercises.count) exercises available")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Rest timer

struct RestBanner: View {
    let end: Date
    let onSkip: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "timer")
            Text("Rest")
            Text(timerInterval: Date()...max(Date(), end), countsDown: true)
                .monospacedDigit()
                .bold()
            Spacer()
            Button("Skip", action: onSkip)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .task(id: end) {
            let wait = end.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            if !Task.isCancelled {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onSkip()
            }
        }
    }
}

extension TodayView {

    fileprivate func groupLabel(_ id: UUID) -> String? {
        guard let w = store.current, let i = w.exercises.firstIndex(where: { $0.id == id }) else { return nil }
        return w.groupLabel(i)
    }

    fileprivate func isLast(_ id: UUID) -> Bool { store.current?.exercises.last?.id == id }
}
