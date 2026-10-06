import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: WorkoutStore
    @EnvironmentObject var spotify: SpotifyManager
    @State private var confirmErase = false
    @State private var editProfile = false
    @State private var healthError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        editProfile = true
                    } label: {
                        Label("Profile, goals & targets", systemImage: "person.crop.circle")
                    }
                    Toggle("Use kilograms", isOn: $store.settings.useKilograms)
                    Toggle("Pair accessories into supersets", isOn: $store.settings.autoSupersets)
                    Toggle("Weekly weigh-in reminder", isOn: Binding(
                        get: { store.settings.weighInReminder },
                        set: { store.settings.weighInReminder = $0; Reminders.update(enabled: $0) }
                    ))
                } header: {
                    Text("You")
                } footer: {
                    Text("\(store.settings.experience.displayName) · \(store.settings.goal.displayName). Change your split and days on the Program tab. Supersets: two exercises back to back, then rest; link any two yourself from an exercise's ⋯ menu.")
                }

                Section {
                    NavigationLink {
                        PreferencesView()
                    } label: {
                        Label("Injuries & exercise preferences", systemImage: "bandage")
                    }
                    NavigationLink {
                        CustomExercisesView()
                    } label: {
                        LabeledContent {
                            Text("\(store.settings.customExercises.count)")
                        } label: {
                            Label("My exercises", systemImage: "plus.square.on.square")
                        }
                    }
                } footer: {
                    Text(preferencesSummary)
                }

                Section {
                    Toggle(isOn: $store.settings.abhiMode) {
                        Label("Abhi mode", systemImage: "paintpalette.fill")
                    }
                } header: {
                    Text("Look")
                } footer: {
                    Text("Turns the whole app purple — colours, charts, recovery map, the Watch app and the app icon.")
                }

                Section {
                    ForEach(store.settings.profiles) { profile in
                        NavigationLink {
                            EquipmentProfileEditor(profileID: profile.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(profile.name)
                                    Text("\(ExerciseLibrary.available(with: profile.equipment).count) exercises available")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if profile.id == store.settings.activeProfile.id {
                                    Text("Active").font(.caption.bold()).foregroundStyle(Theme.accent)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        guard store.settings.profiles.count - offsets.count >= 1 else { return }
                        store.settings.profiles.remove(atOffsets: offsets)
                    }
                    Button {
                        let p = EquipmentProfile(name: "New Setup", equipment: [.bodyweight])
                        store.settings.profiles.append(p)
                    } label: {
                        Label("Add equipment setup", systemImage: "plus")
                    }
                } header: {
                    Text("My Equipment")
                } footer: {
                    Text("Workouts only use exercises you can do with the active setup. Switch setups on the Workout tab.")
                }

                Section {
                    Toggle("Save workouts to Apple Health", isOn: Binding(
                        get: { store.settings.healthEnabled },
                        set: { on in
                            if on {
                                Task { healthError = await store.connectHealth() }
                            } else {
                                store.settings.healthEnabled = false
                            }
                        }
                    ))
                    Button {
                        Task { healthError = await store.connectHealth() }
                    } label: {
                        Label(store.settings.healthEnabled ? "Reconnect Apple Health" : "Connect Apple Health", systemImage: "heart.text.square")
                    }
                    if let healthError {
                        Text("Couldn't connect: \(healthError)")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else if store.settings.healthEnabled {
                        Label(store.health.canSaveWorkouts ? "Connected" : "Connected, but saving workouts is off in the Health app",
                              systemImage: store.health.canSaveWorkouts ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(store.health.canSaveWorkouts ? .green : .orange)
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Calories come from your Apple Watch sensors when it recorded them, otherwise from your heart rate, otherwise an estimate. To change what Forge can read or save: Health app → your profile picture → Apps → Forge.")
                }

                ICloudBackupSection(backup: store.backup)

                SpotifySettingsSection()

                Section {
                    Button("Erase All Data", role: .destructive) { confirmErase = true }
                } footer: {
                    Text("Forge — private build. Your data stays on your devices and your iCloud Drive.")
                }
            }
            .forgeScreen()
            .navigationTitle("Settings")
            .sheet(isPresented: $editProfile) { OnboardingView(mode: .edit) }
            .confirmationDialog("Erase all workouts and settings on this iPhone?", isPresented: $confirmErase, titleVisibility: .visible) {
                Button("Erase", role: .destructive) { store.eraseAll() }
            } message: {
                Text("Your iCloud Drive backup will be overwritten too.")
            }
        }
    }
}

struct EquipmentProfileEditor: View {
    @EnvironmentObject var store: WorkoutStore
    let profileID: UUID

    private var index: Int? { store.settings.profiles.firstIndex { $0.id == profileID } }

    var body: some View {
        Form {
            if let i = index {
                Section {
                    Button("Use this setup") { store.setActiveProfile(profileID) }
                        .disabled(store.settings.activeProfile.id == profileID)
                }
                EquipmentEditor(profile: $store.settings.profiles[i], customMap: $store.settings.customMachineMap)
            }
        }
        .forgeScreen()
        .navigationTitle(index.map { store.settings.profiles[$0].name } ?? "Setup")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension SettingsView {
    var preferencesSummary: String {
        let s = store.settings
        var parts: [String] = []
        if !s.injuries.isEmpty { parts.append("Working around: " + Injury.allCases.filter { s.injuries.contains($0) }.map(\.displayName).joined(separator: ", ")) }
        let more = s.exercisePreferences.values.filter { $0 == .more }.count
        let less = s.exercisePreferences.values.filter { $0 == .less }.count
        if more > 0 { parts.append("\(more) more often") }
        if less > 0 { parts.append("\(less) less often") }
        if !s.excludedExerciseIDs.isEmpty { parts.append("\(s.excludedExerciseIDs.count) never") }
        return parts.isEmpty ? "Tell Forge about sore joints and which exercises you like or don't." : parts.joined(separator: " · ")
    }
}

/// Injuries to work around, plus exercises to pick more often, less often, or never.
struct PreferencesView: View {
    @EnvironmentObject var store: WorkoutStore
    @State private var picking = false

    private var injuryBlocked: [Exercise] {
        let ids = store.settings.injuries.reduce(Set<String>()) { $0.union($1.avoid) }
        return ExerciseLibrary.all.filter { ids.contains($0.id) }
    }

    var body: some View {
        Form {
            Section {
                ForEach(Injury.allCases) { injury in
                    Toggle(injury.displayName, isOn: Binding(
                        get: { store.settings.injuries.contains(injury) },
                        set: { on in
                            if on { store.settings.injuries.insert(injury) } else { store.settings.injuries.remove(injury) }
                        }
                    ))
                }
            } header: {
                Text("Injuries & sore spots")
            } footer: {
                if injuryBlocked.isEmpty {
                    Text("Forge skips exercises that load a marked area hard and picks gentler ones less often. This is a general guide, not medical advice; follow your physio or doctor.")
                } else {
                    Text("Skipping \(injuryBlocked.count) exercises: \(injuryBlocked.map(\.name).joined(separator: ", ")).")
                }
            }

            ForEach(ExercisePreference.allCases, id: \.self) { pref in
                let ids = store.settings.exercisePreferences.filter { $0.value == pref }.map(\.key).sorted {
                    (ExerciseLibrary.byID[$0]?.name ?? $0) < (ExerciseLibrary.byID[$1]?.name ?? $1)
                }
                Section(pref.displayName) {
                    if ids.isEmpty {
                        Text("None yet. Use an exercise's ⋯ menu in a workout, or add one below.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    ForEach(ids, id: \.self) { id in
                        HStack {
                            Text(ExerciseLibrary.byID[id]?.name ?? id)
                            Spacer()
                            Button("Clear") { store.settings.exercisePreferences[id] = nil }
                                .buttonStyle(.borderless)
                        }
                    }
                }
            }

            Section("Never") {
                if store.settings.excludedExerciseIDs.isEmpty {
                    Text("None hidden.").font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(Array(store.settings.excludedExerciseIDs).sorted(), id: \.self) { id in
                    HStack {
                        Text(ExerciseLibrary.byID[id]?.name ?? id)
                        Spacer()
                        Button("Show again") { store.settings.excludedExerciseIDs.remove(id) }
                            .buttonStyle(.borderless)
                    }
                }
            }

            Section {
                Button { picking = true } label: { Label("Set an exercise preference", systemImage: "plus") }
            }
        }
        .forgeScreen()
        .navigationTitle("Preferences")
        .sheet(isPresented: $picking) {
            PreferencePicker()
        }
    }
}

/// Pick any exercise and choose more often, less often or never.
struct PreferencePicker: View {
    @EnvironmentObject var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var exercises: [Exercise] {
        let all = ExerciseLibrary.all
        guard !search.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(exercises) { ex in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ex.name)
                        if let injury = store.settings.blockingInjury(ex.id) {
                            Text("Skipped for your \(injury.displayName.lowercased())")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    Menu {
                        Button("More often") { set(ex.id, .more) }
                        Button("Less often") { set(ex.id, .less) }
                        Button("Never") {
                            store.settings.exercisePreferences[ex.id] = nil
                            store.settings.excludedExerciseIDs.insert(ex.id)
                        }
                        Button("No preference") {
                            store.settings.exercisePreferences[ex.id] = nil
                            store.settings.excludedExerciseIDs.remove(ex.id)
                        }
                    } label: {
                        Text(label(ex.id)).font(.subheadline)
                    }
                }
            }
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func set(_ id: String, _ pref: ExercisePreference) {
        store.settings.excludedExerciseIDs.remove(id)
        store.settings.exercisePreferences[id] = pref
    }

    private func label(_ id: String) -> String {
        if store.settings.excludedExerciseIDs.contains(id) { return "Never" }
        return store.settings.exercisePreferences[id]?.displayName ?? "Normal"
    }
}

struct ICloudBackupSection: View {
    @EnvironmentObject var store: WorkoutStore
    @ObservedObject var backup: CloudBackup
    @State private var picking = false
    @State private var confirmRestore = false
    @State private var restoredMessage: String?

    var body: some View {
        Section {
            if let folder = backup.folderName {
                HStack {
                    Label(folder, systemImage: "icloud.fill")
                    Spacer()
                    if let last = backup.lastBackup {
                        Text(last.formatted(.relative(presentation: .named)))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Button("Back up now") { store.backupNow() }
                Button("Restore from iCloud Drive") { confirmRestore = true }
                Button("Change folder") { picking = true }
                Button("Stop backing up", role: .destructive) { backup.disconnect() }
            } else {
                Button {
                    picking = true
                } label: {
                    Label("Choose iCloud Drive folder", systemImage: "icloud.and.arrow.up")
                }
            }
            if backup.awaitingRestoreDecision {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This folder already has a Forge backup.").font(.subheadline.bold())
                    HStack {
                        Button("Restore it") {
                            restoredMessage = store.restoreFromBackup() ? "Restored \(store.history.count) workouts." : nil
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Overwrite with this iPhone") {
                            backup.awaitingRestoreDecision = false
                            store.backupNow()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            if let err = backup.lastError {
                Text(err).font(.caption).foregroundStyle(.red)
            }
            if let msg = restoredMessage {
                Text(msg).font(.caption).foregroundStyle(ForgeColors.positive)
            }
        } header: {
            Text("iCloud Drive")
        } footer: {
            Text("Pick or create a folder in iCloud Drive (for example “Forge”). Forge saves \(CloudBackup.fileName) there after every change, so your data survives reinstalls and is available on a new iPhone.")
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                backup.setFolder(url)
                store.backupNow()
            }
        }
        .confirmationDialog("Replace everything on this iPhone with the iCloud Drive backup?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Restore", role: .destructive) {
                restoredMessage = store.restoreFromBackup() ? "Restored \(store.history.count) workouts." : nil
            }
        }
    }
}

struct SpotifySettingsSection: View {
    @EnvironmentObject var store: WorkoutStore
    @EnvironmentObject var spotify: SpotifyManager
    @State private var showHelp = false

    var body: some View {
        Section {
            TextField("Workout playlist link (optional)", text: $store.settings.spotifyPlaylistURI)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.subheadline)
            TextField("Spotify Client ID (optional)", text: $store.settings.spotifyClientID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.subheadline.monospaced())
                .onChange(of: store.settings.spotifyClientID) { _, id in spotify.configure(clientID: id) }
            if spotify.isConnected {
                Label("Spotify connected", systemImage: "checkmark.circle.fill").foregroundStyle(ForgeColors.positive)
                Button("Disconnect Spotify", role: .destructive) { spotify.disconnect() }
            } else {
                Button("Connect Spotify account") { spotify.connect(clientID: store.settings.spotifyClientID) }
                    .disabled(store.settings.spotifyClientID.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let msg = spotify.message {
                Text(msg).font(.caption).foregroundStyle(.orange)
            }
            DisclosureGroup("How to get a Client ID", isExpanded: $showHelp) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("1. Go to developer.spotify.com/dashboard and log in.")
                    Text("2. Create app → any name, Redirect URI: \(SpotifyManager.redirectURI)")
                    Text("3. Tick “Web API”, save, then copy the Client ID here.")
                    Text("Controlling playback needs Spotify Premium. Without a Client ID you can still open your playlist link in Spotify.")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
                .textSelection(.enabled)
            }
        } header: {
            Text("Spotify")
        } footer: {
            Text("On Apple Watch, the music controls on the workout screen control Spotify playing on your iPhone.")
        }
    }
}
