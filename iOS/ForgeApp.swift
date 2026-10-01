import SwiftUI

@main
struct ForgeApp: App {
    @StateObject private var store = WorkoutStore()
    @StateObject private var spotify = SpotifyManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(spotify)
                .tint(Theme.accent)
                .onAppear { spotify.configure(clientID: store.settings.spotifyClientID) }
        }
    }
}

enum Theme {
    static let accent = Color(red: 1.0, green: 0.42, blue: 0.16)

    /// Red (fatigued) → yellow → green (fresh).
    static func recoveryColor(_ value: Double) -> Color {
        Color(hue: 0.33 * max(0, min(1, value)), saturation: 0.78, brightness: 0.88)
    }

    static func formatWeight(_ w: Double) -> String {
        w.formatted(.number.precision(.fractionLength(0...1)))
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Workout", systemImage: "dumbbell.fill") }
            RecoveryView()
                .tabItem { Label("Recovery", systemImage: "figure.strengthtraining.traditional") }
            HistoryView()
                .tabItem { Label("History", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
