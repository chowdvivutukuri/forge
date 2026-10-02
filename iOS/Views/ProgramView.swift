import SwiftUI

struct ProgramView: View {
    @EnvironmentObject var store: WorkoutStore
    @State private var preview: [Workout] = []
    @State private var form: FormSheetID?
    @State private var started = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Split", selection: Binding(
                        get: { store.settings.split },
                        set: { store.settings.split = $0; store.settings.programDay = 0 }
                    )) {
                        ForEach(ProgramSplit.allCases) { s in
                            Text(s.displayName + (s == ProgramSplit.recommended(days: store.settings.daysPerWeek) ? " ★" : "")).tag(s)
                        }
                    }
                    Stepper("\(store.settings.daysPerWeek) days a week", value: Binding(
                        get: { store.settings.daysPerWeek },
                        set: { store.settings.daysPerWeek = $0; store.settings.programDay = 0 }
                    ), in: 2...6)
                    Picker("Session length", selection: Binding(
                        get: { store.settings.sessionMinutes },
                        set: {
                            store.settings.sessionMinutes = $0
                            store.settings.exercisesPerWorkout = UserSettings.exercises(forMinutes: $0)
                        }
                    )) {
                        ForEach([30, 45, 60, 75, 90], id: \.self) { Text("\($0) min").tag($0) }
                    }
                    Picker("Goal", selection: $store.settings.goal) {
                        ForEach(TrainingGoal.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Cardio", selection: $store.settings.cardioPlan) {
                        ForEach(CardioPlan.allCases) { Text($0.displayName).tag($0) }
                    }
                } header: {
                    Text("Your plan")
                } footer: {
                    let hasCardio = Equipment.cardioMachines.contains { $0.isCovered(by: store.settings.activeProfile.equipment) }
                    Text(store.settings.split.blurb + " ★ = recommended for \(store.settings.daysPerWeek) days."
                         + (store.settings.cardioPlan != .off && !hasCardio ? " Cardio needs a treadmill or elliptical in your equipment." : ""))
                }

                Section {
                    let weekdays = ProgramSplit.suggestedWeekdays(days: store.settings.daysPerWeek)
                    ForEach(Array(preview.enumerated()), id: \.offset) { i, w in
                        DayCard(index: i, workout: w, isNext: i == store.programDayIndex,
                                weekday: i < weekdays.count ? Theme.weekdayName(weekdays[i]) : nil,
                                unit: store.settings.weightUnit,
                                onForm: { form = FormSheetID(id: $0) },
                                onStart: {
                                    store.startProgramDay(i)
                                    started = true
                                })
                    }
                } header: {
                    Text("Day 1 to \(store.settings.daysPerWeek) · “\(store.settings.activeProfile.name)” equipment")
                } footer: {
                    Text("Suggested days are a guide; train whenever suits you. After you finish a day, the next one comes up on the Workout tab. Exact exercises can shift with recovery.")
                }
            }
            .navigationTitle("Program")
            .sheet(item: $form) { FormDetailView(exerciseID: $0.id) }
            .alert("Workout ready", isPresented: $started) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Open the Workout tab to start logging.")
            }
            .onAppear(perform: refresh)
            .onChange(of: store.settings) { _, _ in refresh() }
            .onChange(of: store.history.count) { _, _ in refresh() }
        }
    }

    private func refresh() { preview = store.generator.programPreview() }
}

private struct DayCard: View {
    @EnvironmentObject var store: WorkoutStore
    let index: Int
    let workout: Workout
    let isNext: Bool
    let weekday: String?
    let unit: String

    private func detail(_ item: WorkoutExercise) -> String {
        if item.isCardio { return Cardio.summary(item, settings: store.settings) }
        let w = item.sets.first?.weight ?? 0
        let base = "\(item.sets.count)×\(item.sets.first?.reps ?? 0)"
        return w > 0 ? base + " · \(Theme.formatWeight(w)) \(unit)" : base
    }
    var onForm: (String) -> Void
    var onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DAY \(index + 1)").font(.caption.weight(.bold)).foregroundStyle(isNext ? Theme.accent : .secondary)
                if let weekday { Text("· \(weekday)").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                if isNext { Chip(text: "Next up", style: .good) }
            }
            Text(workout.title.components(separatedBy: " · ").last ?? workout.title).font(.title3.bold())
            ForEach(workout.exercises) { item in
                Button {
                    onForm(item.exerciseID)
                } label: {
                    HStack(spacing: 10) {
                        FormFigureView(exerciseID: item.exerciseID, animating: false)
                            .frame(width: 34, height: 34)
                        Text(item.name).foregroundStyle(.primary)
                        Spacer()
                        Text(detail(item))
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.borderless)
            }
            Button(action: onStart) {
                Label("Start Day \(index + 1)", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.top, 2)
        }
        .padding(.vertical, 6)
    }
}
