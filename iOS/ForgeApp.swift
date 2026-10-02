import SwiftUI
import UIKit

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
        .foregroundStyle(store.settings.abhiMode ? ForgeColors.ink : Color.primary)
        .preferredColorScheme(store.settings.abhiMode ? .light : nil)
        .id(store.settings.abhiMode)
        .fullScreenCover(isPresented: Binding(
            get: { !store.settings.onboarded },
            set: { _ in }
        )) {
            OnboardingView(mode: .firstRun)
                .environmentObject(store)
        }
    }
}

// MARK: - Abhi mode styling

extension View {
    /// Light purple screen background in Abhi mode (normal system background otherwise).
    func forgeScreen() -> some View {
        modifier(ForgeScreen())
    }
}

struct ForgeScreen: ViewModifier {
    func body(content: Content) -> some View {
        if ForgeColors.abhiMode {
            content
                .scrollContentBackground(.hidden)
                .background(ForgeColors.lavender.ignoresSafeArea())
        } else {
            content
        }
    }
}

enum AbhiAppearance {
    /// Navigation and tab bars are UIKit, so they're styled through appearance proxies.
    static func apply(_ on: Bool) {
        let nav = UINavigationBarAppearance()
        let tab = UITabBarAppearance()
        if on {
            let ink = UIColor(ForgeColors.ink)
            nav.configureWithOpaqueBackground()
            nav.backgroundColor = UIColor(ForgeColors.lavender)
            nav.shadowColor = .clear
            nav.titleTextAttributes = [.foregroundColor: ink]
            nav.largeTitleTextAttributes = [.foregroundColor: ink]
            tab.configureWithOpaqueBackground()
            tab.backgroundColor = UIColor(ForgeColors.lavender)
            let item = tab.stackedLayoutAppearance
            item.normal.iconColor = ink.withAlphaComponent(0.55)
            item.normal.titleTextAttributes = [.foregroundColor: ink.withAlphaComponent(0.55)]
        } else {
            nav.configureWithDefaultBackground()
            tab.configureWithDefaultBackground()
        }
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = on ? nav : nil
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = on ? tab : nil
    }
}
