import SwiftUI
import UserNotifications

/// First-run setup (and "Edit profile & goals" later): body stats, level, goal, targets, schedule, equipment.
struct OnboardingView: View {
    enum Mode { case firstRun, edit }
    let mode: Mode

    @EnvironmentObject var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    enum Step: Int, CaseIterable { case welcome, body, level, goal, schedule, equipment, strength, finish }

    @State private var step: Step = .welcome
    @State private var draft = UserSettings()
    @State private var weightText = ""
    @State private var targetText = ""
    @State private var useTargetDate = false
    @State private var heightCm = 175.0
    @State private var feet = 5
    @State private var inches = 9
    @State private var profileIndex = 0
    @State private var liftTargets: [String: Double] = [:]
    @State private var liftOn: Set<String> = []

    private var steps: [Step] { mode == .firstRun ? Step.allCases : Step.allCases.filter { $0 != .welcome } }
    private var unit: String { draft.useKilograms ? "kg" : "lb" }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .welcome: welcome
                case .body: bodyStep
                case .level: levelStep
                case .goal: goalStep
                case .schedule: scheduleStep
                case .equipment: equipmentStep
                case .strength: strengthStep
                case .finish: finishStep
                }
            }
            .forgeScreen()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if mode == .edit {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                }
            }
            .safeAreaInset(edge: .bottom) { footer }
        }
        .interactiveDismissDisabled(mode == .firstRun)
        .onAppear(perform: load)
    }

    private var title: String {
        switch step {
        case .welcome: return ""
        case .body: return "About you"
        case .level: return "Experience"
        case .goal: return "Your goal"
        case .schedule: return "Your schedule"
        case .equipment: return "Your equipment"
        case .strength: return "Strength targets"
        case .finish: return "Almost done"
        }
    }

    // MARK: Navigation

    private var footer: some View {
        HStack(spacing: 12) {
            if step != steps.first {
                Button("Back") { move(-1) }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
            Button {
                if step == steps.last { finish() } else { move(1) }
            } label: {
                Text(nextLabel)
                    .bold()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .background(.bar)
    }

    private var nextLabel: String {
        if step == steps.last { return mode == .firstRun ? "Start training" : "Save" }
        return step == .welcome ? "Get started" : "Next"
    }

    private func move(_ delta: Int) {
        guard let i = steps.firstIndex(of: step) else { return }
        let j = max(0, min(steps.count - 1, i + delta))
        if steps[j] == .strength { prepareLiftTargets() }
        withAnimation { step = steps[j] }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            FormFigureView(exerciseID: "back_squat", spin: true)
                .frame(width: 220, height: 220)
            Text("Welcome to Forge").font(.largeTitle.bold())
            Text("A few quick questions so your workouts, weights and schedule fit you. You can change any of this later in Settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 28)
            Spacer()
        }
    }

    private var bodyStep: some View {
        Form {
            Section {
                Picker("Units", selection: $draft.useKilograms) {
                    Text("lb / ft").tag(false)
                    Text("kg / cm").tag(true)
                }
                .pickerStyle(.segmented)
            }
            Section {
                Picker("Sex", selection: $draft.sex) {
                    ForEach(Sex.allCases) { Text($0.displayName).tag($0) }
                }
                if draft.useKilograms {
                    Stepper("Height: \(Int(heightCm)) cm", value: $heightCm, in: 120...230)
                } else {
                    Stepper("Height: \(feet) ft", value: $feet, in: 4...7)
                    Stepper("\(inches) in", value: $inches, in: 0...11)
                }
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("0", text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                    Text(unit).foregroundStyle(.secondary)
                }
            } footer: {
                Text("Used to estimate starting weights and track your progress. Sex is only used for those strength estimates.")
            }
        }
    }

    private var levelStep: some View {
        Form {
            Section {
                ForEach(ExperienceLevel.allCases) { level in
                    choiceRow(title: level.displayName, detail: level.blurb, selected: draft.experience == level) {
                        draft.experience = level
                    }
                }
            } footer: {
                Text("Sets your starting weights. If they feel too heavy or too light, just log what you actually lift — Forge adjusts its suggestions to match you.")
            }
        }
    }

    private var goalStep: some View {
        Form {
            Section("Main goal") {
                ForEach(TrainingGoal.allCases) { goal in
                    choiceRow(title: goal.displayName, detail: goal.blurb, selected: draft.goal == goal) {
                        draft.goal = goal
                        if mode == .firstRun { draft.cardioPlan = (goal == .fatLoss || goal == .endurance) ? .finisher : .off }
                    }
                }
            }
            Section {
                HStack {
                    Text("Target weight")
                    Spacer()
                    TextField("optional", text: $targetText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                    Text(unit).foregroundStyle(.secondary)
                }
                Toggle("Target date", isOn: $useTargetDate)
                if useTargetDate {
                    DatePicker("By", selection: Binding(
                        get: { draft.targetDate ?? Calendar.current.date(byAdding: .month, value: 3, to: Date())! },
                        set: { draft.targetDate = $0 }
                    ), in: Date()..., displayedComponents: .date)
                }
            } header: {
                Text("Body weight target")
            } footer: {
                Text("Leave blank if you don't have one. Progress is tracked on the Progress tab.")
            }
        }
    }

    private var scheduleStep: some View {
        Form {
            Section {
                Stepper("\(draft.daysPerWeek) days a week", value: Binding(
                    get: { draft.daysPerWeek },
                    set: { draft.daysPerWeek = $0; draft.split = ProgramSplit.recommended(days: $0) }
                ), in: 2...6)
                Picker("Session length", selection: $draft.sessionMinutes) {
                    ForEach([30, 45, 60, 75, 90], id: \.self) { Text("\($0) min").tag($0) }
                }
                Picker("Cardio", selection: $draft.cardioPlan) {
                    ForEach(CardioPlan.allCases) { Text($0.displayName).tag($0) }
                }
            } header: {
                Text("How often can you train?")
            } footer: {
                Text("Cardio uses a treadmill or elliptical if your equipment has one. You can also start a cardio-only session any time.")
            }
            Section {
                ForEach(ProgramSplit.allCases) { split in
                    choiceRow(title: split.displayName + (split == ProgramSplit.recommended(days: draft.daysPerWeek) ? "  ·  Recommended" : ""),
                              detail: split.blurb, selected: draft.split == split) {
                        draft.split = split
                    }
                }
            } header: {
                Text("Workout split")
            }
            Section("Your week") {
                let days = ProgramSplit.suggestedWeekdays(days: draft.daysPerWeek)
                ForEach(Array(draft.split.schedule(days: draft.daysPerWeek).enumerated()), id: \.offset) { i, focus in
                    HStack {
                        Text("Day \(i + 1)").bold().frame(width: 56, alignment: .leading)
                        Text(focus.displayName)
                        Spacer()
                        if i < days.count { Text(Theme.weekdayName(days[i])).foregroundStyle(.secondary) }
                    }
                }
            }
        }
    }

    private var equipmentStep: some View {
        Form {
            Section {
                Picker("Where do you train?", selection: $profileIndex) {
                    ForEach(Array(draft.profiles.enumerated()), id: \.offset) { i, p in Text(p.name).tag(i) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Add or rename setups later in Settings. Workouts only use what the selected setup has.")
            }
            if draft.profiles.indices.contains(profileIndex) {
                EquipmentEditor(profile: $draft.profiles[profileIndex], customMap: $draft.customMachineMap, showName: false)
            }
        }
    }

    private var strengthStep: some View {
        Form {
            Section {
                ForEach(keyLifts, id: \.self) { id in
                    if let ex = ExerciseLibrary.byID[id] {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                FormFigureView(exerciseID: id).frame(width: 44, height: 44)
                                Toggle(isOn: Binding(
                                    get: { liftOn.contains(id) },
                                    set: { if $0 { liftOn.insert(id) } else { liftOn.remove(id) } }
                                )) {
                                    VStack(alignment: .leading) {
                                        Text(ex.name)
                                        if let now = estimate(id) {
                                            Text("Estimated now: \(Theme.formatWeight(now)) \(unit) (1 rep)")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            if liftOn.contains(id) {
                                Stepper("Target: \(Theme.formatWeight(liftTargets[id] ?? 0)) \(unit)",
                                        value: Binding(get: { liftTargets[id] ?? 0 }, set: { liftTargets[id] = $0 }),
                                        in: 0...2000, step: draft.useKilograms ? 2.5 : 5)
                            }
                        }
                    }
                }
            } footer: {
                Text("Optional. Targets are for a one-rep max, estimated from the sets you log — you never have to test a true max.")
            }
        }
    }

    private var finishStep: some View {
        Form {
            Section {
                Toggle("Save workouts & weigh-ins to Apple Health", isOn: $draft.healthEnabled)
                Toggle("Weekly weigh-in reminder", isOn: $draft.weighInReminder)
            } footer: {
                Text("The reminder comes on Sunday mornings. Weigh yourself at the same time each week for the clearest trend.")
            }
            Section("Summary") {
                LabeledContent("Goal", value: draft.goal.displayName)
                LabeledContent("Level", value: draft.experience.displayName)
                LabeledContent("Program", value: "\(draft.split.displayName), \(draft.daysPerWeek) days")
                LabeledContent("Exercises per workout", value: "\(UserSettings.exercises(forMinutes: draft.sessionMinutes))")
                LabeledContent("Cardio", value: draft.cardioPlan.displayName)
                if draft.profiles.indices.contains(profileIndex) {
                    LabeledContent("Equipment", value: draft.profiles[profileIndex].name)
                }
            }
        }
    }

    private func choiceRow(title: String, detail: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Theme.accent : .secondary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary).bold()
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: Data

    private var keyLifts: [String] {
        let have: Set<Equipment> = draft.profiles.indices.contains(profileIndex)
            ? draft.profiles[profileIndex].equipment.union([Equipment.bodyweight])
            : Set([Equipment.bodyweight])
        let groups: [[String]] = [
            ["bb_bench", "db_bench", "machine_chest", "smith_bench"],
            ["back_squat", "smith_squat", "leg_press", "hack_squat", "goblet_squat"],
            ["deadlift", "bb_rdl", "db_rdl", "kb_swing"],
            ["bb_ohp", "db_ohp", "machine_shoulder"],
            ["bb_row", "lat_pulldown", "cable_row", "db_row"],
        ]
        return groups.compactMap { ids in
            ids.first { id in ExerciseLibrary.byID[id].map { ex in ex.equipment.allSatisfy { $0.isCovered(by: have) } } ?? false }
        }
    }

    private func draftGenerator() -> WorkoutGenerator {
        WorkoutGenerator(settings: draft, history: store.history, bodyWeightKg: parsedWeightKg ?? store.latestWeightKg)
    }

    private func estimate(_ id: String) -> Double? {
        if let s = store.bestSet(for: id) { return WorkoutGenerator.oneRepMax(s) }
        guard let ex = ExerciseLibrary.byID[id] else { return nil }
        return draftGenerator().predictedOneRepMax(ex)
    }

    private func prepareLiftTargets() {
        let st = draft.useKilograms ? 2.5 : 5.0
        for id in keyLifts where liftTargets[id] == nil {
            if let existing = draft.strengthTargets.first(where: { $0.exerciseID == id }) {
                liftTargets[id] = existing.target
                liftOn.insert(id)
            } else if let now = estimate(id) {
                liftTargets[id] = ((now * 1.15) / st).rounded() * st
            }
        }
    }

    private var parsedWeightKg: Double? {
        guard let v = Double(weightText.replacingOccurrences(of: ",", with: ".")), v > 0 else { return nil }
        return draft.kg(fromDisplay: v)
    }

    private func load() {
        draft = store.settings
        if mode == .firstRun { step = .welcome } else { step = .body }
        if let kg = store.latestWeightKg { weightText = Theme.formatWeight(draft.displayWeight(kg: kg)) }
        if let t = draft.targetWeightKg { targetText = Theme.formatWeight(draft.displayWeight(kg: t)) }
        useTargetDate = draft.targetDate != nil
        let cm = draft.heightCm ?? 175
        heightCm = cm.rounded()
        let totalIn = Int((cm / 2.54).rounded())
        feet = totalIn / 12
        inches = totalIn % 12
        profileIndex = draft.profiles.firstIndex { $0.id == draft.activeProfile.id } ?? 0
        if mode == .firstRun { draft.split = ProgramSplit.recommended(days: draft.daysPerWeek) }
    }

    private func finish() {
        var s = draft
        s.heightCm = s.useKilograms ? heightCm : Double(feet * 12 + inches) * 2.54
        if let t = Double(targetText.replacingOccurrences(of: ",", with: ".")), t > 0 {
            s.targetWeightKg = s.kg(fromDisplay: t)
        } else {
            s.targetWeightKg = nil
        }
        if !useTargetDate { s.targetDate = nil } else if s.targetDate == nil {
            s.targetDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())
        }
        s.exercisesPerWorkout = UserSettings.exercises(forMinutes: s.sessionMinutes)
        if s.profiles.indices.contains(profileIndex) { s.activeProfileID = s.profiles[profileIndex].id }
        if store.settings.split != s.split || store.settings.daysPerWeek != s.daysPerWeek { s.programDay = 0 }
        s.onboarded = true
        let wantsHealth = s.healthEnabled && !store.settings.healthEnabled
        store.settings = s

        if let kg = parsedWeightKg, abs(kg - (store.latestWeightKg ?? 0)) > 0.05 {
            store.logWeight(displayValue: s.displayWeight(kg: kg))
        }
        for id in keyLifts {
            if liftOn.contains(id), let t = liftTargets[id], t > 0 {
                if store.settings.strengthTargets.first(where: { $0.exerciseID == id })?.target != t {
                    store.addStrengthTarget(exerciseID: id, target: t)
                }
            } else {
                store.settings.strengthTargets.removeAll { $0.exerciseID == id }
            }
        }
        if wantsHealth {
            Task {
                let ok = await store.health.requestAuthorization()
                if !ok { store.settings.healthEnabled = false }
            }
        }
        Reminders.update(enabled: s.weighInReminder)
        if mode == .edit { dismiss() }
    }
}

enum Reminders {
    static let weighInID = "forge.weighin"

    static func update(enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [weighInID])
        guard enabled else { return }
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Weekly weigh-in"
            content.body = "Log your weight in Forge to keep your progress up to date."
            var when = DateComponents()
            when.weekday = 1   // Sunday
            when.hour = 8
            when.minute = 30
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
            center.add(UNNotificationRequest(identifier: weighInID, content: content, trigger: trigger))
        }
    }
}
