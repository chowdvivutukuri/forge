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
                .onAppear { spotify.configure(clientID: store.settings.spotifyClientID) }
        }
    }
}

enum Theme {
    static var accent: Color { ForgeColors.accent }

    /// Red (fatigued) → yellow → green (fresh). In Abhi mode: deep purple (fatigued) → lavender (fresh).
    static func recoveryColor(_ value: Double) -> Color {
        let v = max(0, min(1, value))
        if ForgeColors.abhiMode {
            return Color(hue: 0.76 - 0.04 * v, saturation: 0.85 - 0.55 * v, brightness: 0.45 + 0.5 * v)
        }
        return Color(hue: 0.33 * v, saturation: 0.78, brightness: 0.88)
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
        .tint(Theme.accent)
        .fullScreenCover(isPresented: Binding(
            get: { !store.settings.onboarded },
            set: { _ in }
        )) {
            OnboardingView(mode: .firstRun)
                .environmentObject(store)
        }
    }
}
