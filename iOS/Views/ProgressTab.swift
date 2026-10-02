import SwiftUI
import Charts

struct ProgressTab: View {
    @EnvironmentObject var store: WorkoutStore
    @State private var showWeigh = false
    @State private var addTarget = false
    @State private var editProfile = false

    private var s: UserSettings { store.settings }
    private var unit: String { s.weightUnit }

    var body: some View {
        NavigationStack {
            List {
                bodyWeightSection
                consistencySection
                strengthSection
                if !store.history.isEmpty { volumeSection }
                historySection
            }
            .forgeScreen()
            .navigationTitle("Progress")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Goals") { editProfile = true }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let w = store.history.first(where: { $0.id == id }) {
                    WorkoutDetailView(workout: w)
                }
            }
            .sheet(isPresented: $showWeigh) { WeighInSheet() }
            .sheet(isPresented: $addTarget) { AddTargetSheet() }
            .sheet(isPresented: $editProfile) { OnboardingView(mode: .edit) }
        }
    }

    // MARK: Body weight

    @ViewBuilder private var bodyWeightSection: some View {
        Section {
            if let latest = store.latestWeightKg {
                let now = s.displayWeight(kg: latest)
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading) {
                        Text("Now").font(.caption).foregroundStyle(.secondary)
                        Text("\(Theme.formatWeight(now)) \(unit)").font(.title2.bold())
                    }
                    Spacer()
                    if let start = store.startWeightKg, store.weighIns.count > 1 {
                        let change = now - s.displayWeight(kg: start)
                        VStack(alignment: .trailing) {
                            Text("Since start").font(.caption).foregroundStyle(.secondary)
                            Text("\(change >= 0 ? "+" : "")\(Theme.formatWeight(change)) \(unit)").font(.headline)
                        }
                    }
                    if let target = s.targetWeightKg {
                        VStack(alignment: .trailing) {
                            Text("Target").font(.caption).foregroundStyle(.secondary)
                            Text("\(Theme.formatWeight(s.displayWeight(kg: target))) \(unit)").font(.headline)
                        }
                        .padding(.leading, 12)
                    }
                }
                if let target = s.targetWeightKg, let start = store.startWeightKg, abs(start - target) > 0.1 {
                    let progress: Double = start > target
                        ? Self.progress(current: -latest, start: -start, target: -target)
                        : Self.progress(current: latest, start: start, target: target)
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: progress).tint(Theme.accent)
                        Text(targetLine(progress: progress, latest: latest, target: target))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if store.weighIns.count > 1 {
                    Chart {
                        ForEach(store.weighIns) { w in
                            LineMark(x: .value("Date", w.date), y: .value("Weight", s.displayWeight(kg: w.kg)))
                                .interpolationMethod(.monotone)
                            PointMark(x: .value("Date", w.date), y: .value("Weight", s.displayWeight(kg: w.kg)))
                                .symbolSize(24)
                        }
                        .foregroundStyle(Theme.accent)
                        if let target = s.targetWeightKg {
                            RuleMark(y: .value("Target", s.displayWeight(kg: target)))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                .foregroundStyle(.secondary)
                                .annotation(position: .top, alignment: .leading) {
                                    Text("Target").font(.caption2).foregroundStyle(.secondary)
                                }
                        }
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 170)
                }
            } else {
                Text("No weigh-ins yet.").foregroundStyle(.secondary)
            }
            Button { showWeigh = true } label: { Label("Log weight", systemImage: "scalemass") }
            if !store.weighIns.isEmpty {
                NavigationLink("All weigh-ins") { WeighInListView() }
            }
        } header: {
            Text("Body weight")
        }
    }

    private func targetLine(progress: Double, latest: Double, target: Double) -> String {
        let left = abs(s.displayWeight(kg: latest) - s.displayWeight(kg: target))
        var text = "\(Int((progress * 100).rounded()))% of the way · \(Theme.formatWeight(left)) \(unit) to go"
        if let date = s.targetDate {
            let weeks = max(0, Int((date.timeIntervalSinceNow / (7 * 86_400)).rounded()))
            text += " · \(weeks) weeks left"
        }
        return text
    }

    // MARK: Consistency

    private var consistencySection: some View {
        Section("Consistency") {
            let thisWeek = store.workouts(inWeekOf: Date()).count
            HStack {
                Text("This week")
                Spacer()
                Text("\(thisWeek) of \(s.daysPerWeek) workouts").bold()
            }
            ProgressView(value: min(1, Double(thisWeek) / Double(max(1, s.daysPerWeek)))).tint(ForgeColors.positive)
            let cardioMinutes = store.workouts(inWeekOf: Date()).flatMap(\.exercises).filter(\.isCardio).map(\.cardioMinutes).reduce(0, +)
            if cardioMinutes > 0 || s.cardioPlan != .off {
                HStack {
                    Label("Cardio this week", systemImage: "figure.run")
                    Spacer()
                    Text("\(Int(cardioMinutes.rounded())) min").bold()
                }
            }
            HStack(spacing: 6) {
                ForEach(0..<8, id: \.self) { i in
                    let date = Calendar.current.date(byAdding: .weekOfYear, value: i - 7, to: Date()) ?? Date()
                    let n = store.workouts(inWeekOf: date).count
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(weekColor(n))
                            .frame(height: 22)
                        Text("\(n)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
            Text("Last 8 weeks — a full bar means you hit your \(s.daysPerWeek) days.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: Strength targets

    private var strengthSection: some View {
        Section {
            if s.strengthTargets.isEmpty {
                Text("Set a target for a lift you care about, like your bench press or squat.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(s.strengthTargets) { t in
                let ex = ExerciseLibrary.byID[t.exerciseID]
                let current = store.bestSet(for: t.exerciseID).map(WorkoutGenerator.oneRepMax) ?? t.start
                let progress: Double = Self.progress(current: current, start: t.start, target: t.target)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        FormFigureView(exerciseID: t.exerciseID, animating: false).frame(width: 36, height: 36)
                        VStack(alignment: .leading) {
                            Text(ex?.name ?? t.exerciseID).bold()
                            Text("\(Theme.formatWeight(current)) → \(Theme.formatWeight(t.target)) \(unit) (est. 1-rep max)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int((progress * 100).rounded()))%").font(.headline.monospacedDigit())
                    }
                    ProgressView(value: progress).tint(progress >= 1 ? ForgeColors.positive : Theme.accent)
                }
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        store.settings.strengthTargets.removeAll { $0.id == t.id }
                    }
                }
            }
            Button { addTarget = true } label: { Label("Add strength target", systemImage: "target") }
        } header: {
            Text("Strength targets")
        }
    }

    private func weekColor(_ n: Int) -> Color {
        if n >= s.daysPerWeek { return ForgeColors.positive }
        if n > 0 { return ForgeColors.positive.opacity(0.4) }
        return Color.secondary.opacity(0.15)
    }

    static func progress(current: Double, start: Double, target: Double) -> Double {
        let span: Double = target - start
        if span <= 0 { return current >= target ? 1.0 : 0.0 }
        let raw: Double = (current - start) / span
        return Swift.max(0.0, Swift.min(1.0, raw))
    }

    // MARK: Volume + history

    private var volumeSection: some View {
        Section("Volume per workout") {
            Chart(store.history.suffix(16)) { w in
                BarMark(x: .value("Date", w.finishedAt ?? w.createdAt, unit: .day),
                        y: .value("Volume", w.volume))
                    .foregroundStyle(Theme.accent)
            }
            .frame(height: 150)
        }
    }

    private var historySection: some View {
        Section("Workouts") {
            if store.history.isEmpty {
                Text("Finished workouts show up here.").foregroundStyle(.secondary)
            }
            let items = Array(store.history.reversed())
            ForEach(items) { w in
                NavigationLink(value: w.id) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(w.title).font(.headline)
                        Text((w.finishedAt ?? w.createdAt).formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                        Text("\(w.completedSetCount) sets · \(Theme.formatWeight(w.volume)) \(unit) volume")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                offsets.map { items[$0].id }.forEach(store.deleteWorkout)
            }
        }
    }
}

struct WeighInSheet: View {
    @EnvironmentObject var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                HStack {
                    TextField("Weight", text: $text).keyboardType(.decimalPad)
                    Text(store.settings.weightUnit).foregroundStyle(.secondary)
                }
                DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
            }
            .forgeScreen()
            .navigationTitle("Log weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let v = Double(text.replacingOccurrences(of: ",", with: ".")) {
                            store.logWeight(displayValue: v, date: date)
                        }
                        dismiss()
                    }
                    .disabled(Double(text.replacingOccurrences(of: ",", with: ".")) == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct WeighInListView: View {
    @EnvironmentObject var store: WorkoutStore

    var body: some View {
        let items = Array(store.weighIns.reversed())
        List {
            ForEach(items) { w in
                HStack {
                    Text(w.date.formatted(date: .abbreviated, time: .omitted))
                    Spacer()
                    Text("\(Theme.formatWeight(store.settings.displayWeight(kg: w.kg))) \(store.settings.weightUnit)")
                        .monospacedDigit()
                }
            }
            .onDelete { offsets in offsets.map { items[$0].id }.forEach(store.deleteWeighIn) }
        }
        .forgeScreen()
        .navigationTitle("Weigh-ins")
    }
}

struct AddTargetSheet: View {
    @EnvironmentObject var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var exerciseID = ""
    @State private var target: Double = 0

    private var options: [Exercise] {
        store.generator.availableExercises.filter { !$0.isBodyweight && !$0.isCardio }.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Exercise", selection: $exerciseID) {
                    ForEach(options) { Text($0.name).tag($0.id) }
                }
                if let now = store.currentOneRepMax(exerciseID) {
                    LabeledContent("Estimated now", value: "\(Theme.formatWeight(now)) \(store.settings.weightUnit)")
                }
                Stepper("Target: \(Theme.formatWeight(target)) \(store.settings.weightUnit)", value: $target, in: 0...2000,
                        step: store.settings.useKilograms ? 2.5 : 5)
            }
            .forgeScreen()
            .navigationTitle("Strength target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addStrengthTarget(exerciseID: exerciseID, target: target)
                        dismiss()
                    }
                    .disabled(exerciseID.isEmpty || target <= 0)
                }
            }
            .onAppear {
                if exerciseID.isEmpty { exerciseID = options.first?.id ?? "" }
                suggest()
            }
            .onChange(of: exerciseID) { _, _ in suggest() }
        }
    }

    private func suggest() {
        let step = store.settings.useKilograms ? 2.5 : 5.0
        if let now = store.currentOneRepMax(exerciseID) { target = ((now * 1.15) / step).rounded() * step }
    }
}
