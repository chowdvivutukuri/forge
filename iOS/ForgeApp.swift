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
    static let accent = Color(red: 0.89, green: 0.35, blue: 0.12)

    /// Red (fatigued) → yellow → green (fresh).
    static func recoveryColor(_ value: Double) -> Color {
        Color(hue: 0.33 * max(0, min(1, value)), saturation: 0.78, brightness: 0.88)
    }

    static func formatWeight(_ w: Double) -> String {
        w.formatted(.number.precision(.fractionLength(0...1)))
    }

    static func weekdayName(_ isoWeekday: Int) -> String {
        // 1 = Monday ... 7 = Sunday
        let symbols = Calendar.current.shortWeekdaySymbols // Sunday first
        return symbols[isoWeekday % 7]
    }
}

struct RootView: View {
    @EnvironmentObject var store: WorkoutStore

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Workout", systemImage: "dumbbell.fill") }
            ProgramView()
                .tabItem { Label("Program", systemImage: "calendar") }
            ProgressTab()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            RecoveryView()
                .tabItem { Label("Recovery", systemImage: "figure.strengthtraining.traditional") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !store.settings.onboarded },
            set: { _ in }
        )) {
            OnboardingView(mode: .firstRun)
                .environmentObject(store)
        }
    }
}
