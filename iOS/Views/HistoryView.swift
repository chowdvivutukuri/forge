import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var store: WorkoutStore

    private var newestFirst: [Workout] { Array(store.history.reversed()) }

    var body: some View {
        NavigationStack {
            List {
                if store.history.isEmpty {
                    ContentUnavailableView("No workouts yet", systemImage: "clock",
                                           description: Text("Finished workouts show up here."))
                } else {
                    Section("Volume per workout") {
                        Chart(store.history.suffix(14)) { w in
                            BarMark(x: .value("Date", w.finishedAt ?? w.createdAt, unit: .day),
                                    y: .value("Volume", w.volume))
                                .foregroundStyle(Theme.accent)
                        }
                        .frame(height: 160)
                        .padding(.vertical, 6)
                    }
                    Section("Workouts") {
                        let items = newestFirst
                        ForEach(items) { w in
                            NavigationLink(value: w.id) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(w.title).font(.headline)
                                    Text((w.finishedAt ?? w.createdAt).formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text("\(w.completedSetCount) sets · \(Theme.formatWeight(w.volume)) \(store.settings.weightUnit) volume")
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
            .navigationTitle("History")
            .navigationDestination(for: UUID.self) { id in
                if let w = store.history.first(where: { $0.id == id }) {
                    WorkoutDetailView(workout: w)
                }
            }
        }
    }
}

struct WorkoutDetailView: View {
    @EnvironmentObject var store: WorkoutStore
    let workout: Workout

    var body: some View {
        List {
            Section {
                stat("Date", (workout.finishedAt ?? workout.createdAt).formatted(date: .complete, time: .shortened))
                if let d = workout.duration {
                    stat("Duration", Duration.seconds(d).formatted(.units(allowed: [.hours, .minutes])))
                }
                stat("Sets completed", "\(workout.completedSetCount)")
                stat("Volume", "\(Theme.formatWeight(workout.volume)) \(store.settings.weightUnit)")
                if let profile = workout.equipmentProfileName { stat("Equipment", profile) }
                if let kcal = workout.calories { stat("Calories", "\(Int(kcal)) kcal") }
                if let hr = workout.averageHeartRate { stat("Avg heart rate", "\(Int(hr)) bpm") }
                if workout.savedToHealth { Label("Saved to Apple Health", systemImage: "heart.fill").foregroundStyle(.pink) }
            }
            ForEach(workout.exercises) { item in
                Section(item.name) {
                    let done = item.sets.filter(\.done)
                    if done.isEmpty {
                        Text("Skipped").foregroundStyle(.secondary)
                    }
                    ForEach(Array(done.enumerated()), id: \.element.id) { i, set in
                        HStack {
                            Text("Set \(i + 1)").foregroundStyle(.secondary)
                            Spacer()
                            Text(set.weight > 0 ? "\(Theme.formatWeight(set.weight)) \(store.settings.weightUnit) × \(set.reps)" : "\(set.reps) reps")
                                .monospacedDigit()
                        }
                    }
                    if let best = store.bestSet(for: item.exerciseID) {
                        Text("Est. 1-rep max: \(Theme.formatWeight(WorkoutGenerator.oneRepMax(best))) \(store.settings.weightUnit)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(workout.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
    }
}
