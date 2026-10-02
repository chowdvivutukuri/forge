import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: WorkoutStore
    @EnvironmentObject var spotify: SpotifyManager
    @State private var confirmErase = false
    @State private var editProfile = false

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
                    Toggle("Weekly weigh-in reminder", isOn: Binding(
                        get: { store.settings.weighInReminder },
                        set: { store.settings.weighInReminder = $0; Reminders.update(enabled: $0) }
                    ))
                } header: {
                    Text("You")
                } footer: {
                    Text("\(store.settings.experience.displayName) · \(store.settings.goal.displayName). Change your split and days on the Program tab.")
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
                                Task {
                                    let ok = await store.health.requestAuthorization()
                                    store.settings.healthEnabled = ok
                                }
                            } else {
                                store.settings.healthEnabled = false
                            }
                        }
                    ))
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Workouts tracked on Apple Watch are saved with heart rate and calories automatically.")
                }

                ICloudBackupSection(backup: store.backup)

                SpotifySettingsSection()

                if !store.settings.excludedExerciseIDs.isEmpty {
                    Section("Hidden exercises") {
                        ForEach(Array(store.settings.excludedExerciseIDs).sorted(), id: \.self) { id in
                            HStack {
                                Text(ExerciseLibrary.byID[id]?.name ?? id)
                                Spacer()
                                Button("Show again") { store.settings.excludedExerciseIDs.remove(id) }
                                    .buttonStyle(.borderless)
                            }
                        }
                    }
                }

                Section {
                    Button("Erase All Data", role: .destructive) { confirmErase = true }
                } footer: {
                    Text("Forge — private build. Your data stays on your devices and your iCloud Drive.")
                }
            }
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
        .navigationTitle(index.map { store.settings.profiles[$0].name } ?? "Setup")
        .navigationBarTitleDisplayMode(.inline)
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
                Text(msg).font(.caption).foregroundStyle(.green)
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
                Label("Spotify connected", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
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
