import SwiftUI

struct SpotifyCard: View {
    @EnvironmentObject var store: WorkoutStore
    @EnvironmentObject var spotify: SpotifyManager
    var compact = false
    @State private var showPlaylists = false

    private let spotifyGreen = Color(red: 0.11, green: 0.73, blue: 0.33)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if spotify.isConnected {
                connected
            } else {
                notConnected
            }
            if let msg = spotify.message {
                Text(msg).font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
        .task(id: spotify.isConnected) {
            guard spotify.isConnected else { return }
            spotify.configure(clientID: store.settings.spotifyClientID)
            if spotify.playlists.isEmpty { await spotify.loadPlaylists() }
            while !Task.isCancelled {
                await spotify.refreshNowPlaying()
                try? await Task.sleep(for: .seconds(6))
            }
        }
        .sheet(isPresented: $showPlaylists) { PlaylistPicker() }
    }

    private var connected: some View {
        HStack(spacing: 12) {
            AsyncImage(url: spotify.nowPlaying?.artURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ZStack {
                    spotifyGreen.opacity(0.2)
                    Image(systemName: "music.note").foregroundStyle(spotifyGreen)
                }
            }
            .frame(width: compact ? 40 : 52, height: compact ? 40 : 52)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(spotify.nowPlaying?.title ?? "Nothing playing")
                    .font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(spotify.nowPlaying?.artist ?? "Pick a playlist to start")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Group {
                Button { Task { await spotify.previous() } } label: { Image(systemName: "backward.fill") }
                Button { Task { await spotify.togglePlay() } } label: {
                    Image(systemName: spotify.nowPlaying?.isPlaying == true ? "pause.fill" : "play.fill").font(.title3)
                }
                Button { Task { await spotify.next() } } label: { Image(systemName: "forward.fill") }
                Button { showPlaylists = true } label: { Image(systemName: "music.note.list") }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private var notConnected: some View {
        let playlist = store.settings.spotifyPlaylistURI
        HStack {
            Image(systemName: "music.note").foregroundStyle(spotifyGreen)
            Text(compact ? "Music" : "Spotify").font(.subheadline.weight(.semibold))
            Spacer()
            Button(playlist.isEmpty ? "Open Spotify" : "Play workout playlist") {
                spotify.openInSpotify(playlist)
            }
            .buttonStyle(.bordered)
            .tint(spotifyGreen)
        }
        if !compact && !store.settings.spotifyClientID.isEmpty {
            Button("Connect Spotify account") { spotify.connect(clientID: store.settings.spotifyClientID) }
                .font(.footnote)
                .buttonStyle(.borderless)
        } else if !compact {
            Text("Add your Spotify details in Settings to see what's playing and control it here.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct PlaylistPicker: View {
    @EnvironmentObject var store: WorkoutStore
    @EnvironmentObject var spotify: SpotifyManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if spotify.playlists.isEmpty {
                    Text("No playlists found.").foregroundStyle(.secondary)
                }
                ForEach(spotify.playlists) { p in
                    Button {
                        Task { await spotify.play(uri: p.uri) }
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            AsyncImage(url: p.imageURL) { $0.resizable().scaledToFill() } placeholder: { Color.secondary.opacity(0.2) }
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            Text(p.name).foregroundStyle(.primary)
                            Spacer()
                            if store.settings.spotifyPlaylistURI == p.uri {
                                Image(systemName: "star.fill").foregroundStyle(.yellow)
                            }
                        }
                    }
                    .swipeActions {
                        Button("Workout default") { store.settings.spotifyPlaylistURI = p.uri }
                            .tint(.yellow)
                    }
                }
            }
            .forgeScreen()
            .navigationTitle("Playlists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await spotify.loadPlaylists() }
        }
    }
}
