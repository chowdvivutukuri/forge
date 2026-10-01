import SwiftUI
import UIKit

struct TodayView: View {
    @EnvironmentObject var store: WorkoutStore
    @State private var pickerTarget: PickerTarget?
    @State private var confirmFinish = false
    @State private var confirmDiscard = false
    @State private var finishing = false
    @State private var restEnd: Date?

    var body: some View {
        NavigationStack {
            Group {
                if store.current != nil { activeWorkout } else { emptyState }
            }
            .navigationTitle(store.current?.title ?? "Today")
            .toolbar {
                if store.current != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("New Workout", systemImage: "arrow.clockwise") { store.generateWorkout() }
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
                Text("Completed sets are saved to History\(store.settings.healthEnabled ? " and Apple Health" : "").")
            }
            .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { store.discardCurrent(); restEnd = nil }
            }
            .safeAreaInset(edge: .bottom) {
                if let restEnd, restEnd > Date() {
                    RestBanner(end: restEnd) { self.restEnd = nil }
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                }
            }
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        List {
            Section {
                EquipmentProfileBar()
            } header: {
                Text("Training with")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested today").font(.subheadline).foregroundStyle(.secondary)
                    Text(store.suggestedFocus.displayName).font(.title.bold())
                    Text("Based on muscle recovery and the equipment in “\(store.settings.activeProfile.name)”.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button {
                        store.generateWorkout()
                    } label: {
                        Label("Generate Workout", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)

                    Menu {
                        ForEach(SplitFocus.allCases.filter { $0 != .auto }) { focus in
                            Button(focus.displayName) { store.generateWorkout(focus: focus) }
                        }
                    } label: {
                        Label("Pick a focus instead", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 6)
            }

            WeekPlanSection()

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
            }

            ForEach(workout.exercises) { $item in
                Section {
                    ExerciseCard(
                        item: $item,
                        unit: store.settings.weightUnit,
                        onSetCompleted: { rest in restEnd = Date().addingTimeInterval(TimeInterval(rest)) },
                        onSwap: { store.swap(itemID: item.id) },
                        onChoose: { pickerTarget = .replace(item.id) },
                        onRemove: { store.remove(itemID: item.id) },
                        onExclude: {
                            store.excludeExercise(item.exerciseID)
                            store.swap(itemID: item.id)
                        }
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
            let gear = store.settings.activeProfile.equipment.subtracting([.bodyweight])
            Text(gear.isEmpty ? "Bodyweight only" : Equipment.allCases.filter { gear.contains($0) }.map(\.displayName).joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(store.generator.availableExercises.count) exercises available")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Week plan

struct WeekPlanSection: View {
    @EnvironmentObject var store: WorkoutStore

    var body: some View {
        Section {
            if store.plan.isEmpty {
                Menu {
                    ForEach(2...6, id: \.self) { n in
                        Button("\(n) workouts") { store.makePlan(sessions: n) }
                    }
                } label: {
                    Label("Plan my week", systemImage: "calendar.badge.plus")
                }
            } else {
                ForEach(store.plan) { w in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.title).font(.headline)
                            Text("\(w.createdAt.formatted(.dateTime.weekday(.wide))) · \(w.exercises.count) exercises")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(w.exercises.prefix(3).map(\.name).joined(separator: ", "))
                                .font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                        }
                        Spacer()
                        Button("Start") { store.startPlanned(w.id) }
                            .buttonStyle(.bordered)
                    }
                }
                Button("Clear plan", role: .destructive) { store.plan = [] }
            }
        } header: {
            Text("This week")
        } footer: {
            if !store.plan.isEmpty {
                Text("Planned with your “\(store.settings.activeProfile.name)” equipment. Weights update when you start each session.")
            }
        }
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
