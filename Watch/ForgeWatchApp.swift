import SwiftUI
import WatchKit

@main
struct ForgeWatchApp: App {
    @StateObject private var store = WatchStore()
    @StateObject private var workoutManager = WatchWorkoutManager()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
                .environmentObject(workoutManager)
                .tint(ForgeColors.accent)
                .id(store.abhiMode)
        }
    }
}

struct WatchRootView: View {
    var body: some View {
        TabView {
            WatchWorkoutView()
                .watchAbhiPage()
            // System Now Playing controls: controls Spotify (or any audio) on the paired iPhone.
            NowPlayingView()
                .watchAbhiPage()
        }
        .tabViewStyle(.verticalPage)
    }
}

struct WatchWorkoutView: View {
    @EnvironmentObject var store: WatchStore
    @EnvironmentObject var manager: WatchWorkoutManager
    @State private var confirmFinish = false
    @State private var finishing = false

    var body: some View {
        NavigationStack {
            if let workout = store.workout {
                List {
                    if manager.isRunning {
                        Section {
                            HStack {
                                Image(systemName: "heart.fill").foregroundStyle(.red)
                                Text(manager.heartRate > 0 ? "\(Int(manager.heartRate))" : "--")
                                    .font(.title3.monospacedDigit())
                                Text("bpm").font(.caption2).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(manager.activeCalories)) kcal")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            if manager.maxHeartRate > 0 {
                                HStack {
                                    Text("avg \(Int(manager.averageHeartRate)) · peak \(Int(manager.maxHeartRate))")
                                    Spacer()
                                    Text("+\(Int(manager.restingCalories)) resting")
                                }
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                            }
                        }
                    }

                    ForEach(workout.exercises) { item in
                        NavigationLink(value: item.id) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).font(.headline).lineLimit(2)
                                Text(item.isCardio ? Cardio.summary(item, settings: store.unitSettings) : "\(item.completedSets)/\(item.sets.count) sets")
                                    .font(.caption)
                                    .foregroundStyle(item.completedSets == item.sets.count ? ForgeColors.positive : Color.secondary)
                            }
                        }
                    }

                    Section {
                        if !manager.isRunning {
                            Button {
                                Task { await manager.start() }
                            } label: {
                                Label("Start Tracking", systemImage: "play.fill")
                            }
                        }
                        Button {
                            confirmFinish = true
                        } label: {
                            Label(finishing ? "Saving…" : "Finish Workout", systemImage: "checkmark")
                        }
                        .disabled(finishing)
                    }
                }
                .watchAbhi()
                .navigationTitle(workout.title)
                .navigationDestination(for: UUID.self) { id in
                    WatchExerciseView(itemID: id)
                }
                .confirmationDialog("Finish workout?", isPresented: $confirmFinish) {
                    Button("Finish") {
                        finishing = true
                        Task {
                            let result = await manager.end()
                            store.finish(calories: result.calories, averageHeartRate: result.averageHeartRate,
                                         maxHeartRate: result.maxHeartRate, savedToHealth: result.saved)
                            finishing = false
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "iphone.gen3")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Generate a workout on your iPhone to start.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }
                .watchAbhi()
                .navigationTitle("Forge")
            }
        }
    }
}

// MARK: - Abhi mode on the watch: purple instead of black backgrounds

extension View {
    @ViewBuilder func watchAbhi() -> some View {
        if ForgeColors.abhiMode {
            self.containerBackground(ForgeColors.watchBackground, for: .navigation)
        } else {
            self
        }
    }

    @ViewBuilder func watchAbhiPage() -> some View {
        if ForgeColors.abhiMode {
            self.containerBackground(ForgeColors.watchBackground, for: .tabView)
        } else {
            self
        }
    }
}
