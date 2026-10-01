import Foundation
import UIKit
import AuthenticationServices
import CryptoKit
import Security

/// Spotify connection using the Spotify Web API with PKCE login (no SDK needed).
/// Playback control requires Spotify Premium and Spotify open on one of your devices.
@MainActor
final class SpotifyManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let redirectURI = "forge-spotify://callback"
    private static let scopes = "user-read-playback-state user-modify-playback-state user-read-currently-playing playlist-read-private playlist-read-collaborative"

    struct NowPlaying: Equatable {
        var title: String
        var artist: String
        var isPlaying: Bool
        var artURL: URL?
    }

    struct Playlist: Identifiable, Hashable {
        var id: String
        var name: String
        var uri: String
        var imageURL: URL?
    }

    @Published private(set) var isConnected = false
    @Published private(set) var nowPlaying: NowPlaying?
    @Published private(set) var playlists: [Playlist] = []
    @Published var message: String?

    private var clientID = ""
    private var accessToken: String?
    private var expiresAt = Date.distantPast
    private var authSession: ASWebAuthenticationSession?

    override init() {
        super.init()
        isConnected = Keychain.read("spotify.refresh") != nil
    }

    func configure(clientID: String) {
        self.clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Login

    func connect(clientID: String) {
        configure(clientID: clientID)
        guard !self.clientID.isEmpty else {
            message = "Add your Spotify Client ID in Settings first."
            return
        }
        let verifier = Self.randomString(64)
        var comps = URLComponents(string: "https://accounts.spotify.com/authorize")!
        comps.queryItems = [
            URLQueryItem(name: "client_id", value: self.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: Self.challenge(for: verifier)),
            URLQueryItem(name: "scope", value: Self.scopes),
        ]
        guard let url = comps.url else { return }
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "forge-spotify") { [weak self] callback, error in
            let code = callback.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
                .queryItems?.first { $0.name == "code" }?.value
            let failed = error != nil
            Task { @MainActor in
                guard let self else { return }
                if let code { await self.exchange(code: code, verifier: verifier) }
                else if !failed { self.message = "Spotify login didn't complete." }
            }
        }
        session.presentationContextProvider = self
        authSession = session
        session.start()
    }

    func disconnect() {
        Keychain.delete("spotify.refresh")
        accessToken = nil
        expiresAt = .distantPast
        isConnected = false
        nowPlaying = nil
        playlists = []
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let expires_in: Double
        let refresh_token: String?
    }

    private func exchange(code: String, verifier: String) async {
        let ok = await tokenRequest([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Self.redirectURI,
            "client_id": clientID,
            "code_verifier": verifier,
        ])
        if ok {
            isConnected = true
            message = nil
            await loadPlaylists()
            await refreshNowPlaying()
        } else {
            message = "Couldn't finish Spotify login. Check the Client ID and that \(Self.redirectURI) is added as a Redirect URI."
        }
    }

    private func tokenRequest(_ form: [String: String]) async -> Bool {
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var comps = URLComponents()
        comps.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
        req.httpBody = comps.percentEncodedQuery?.data(using: .utf8)
        guard let result = try? await URLSession.shared.data(for: req),
              (result.1 as? HTTPURLResponse)?.statusCode == 200,
              let token = try? JSONDecoder().decode(TokenResponse.self, from: result.0) else { return false }
        accessToken = token.access_token
        expiresAt = Date().addingTimeInterval(token.expires_in - 60)
        if let refresh = token.refresh_token { Keychain.save(refresh, for: "spotify.refresh") }
        return true
    }

    private func validToken() async -> String? {
        if let t = accessToken, Date() < expiresAt { return t }
        guard let refresh = Keychain.read("spotify.refresh"), !clientID.isEmpty else { return nil }
        let ok = await tokenRequest(["grant_type": "refresh_token", "refresh_token": refresh, "client_id": clientID])
        if !ok {
            message = "Spotify session expired. Connect again."
            disconnect()
        }
        return ok ? accessToken : nil
    }

    // MARK: Web API

    @discardableResult
    private func api(_ method: String, _ path: String, query: [URLQueryItem] = [], json: [String: Any]? = nil) async -> (Data, Int)? {
        guard let token = await validToken() else { return nil }
        var comps = URLComponents(string: "https://api.spotify.com/v1" + path)!
        if !query.isEmpty { comps.queryItems = query }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let json {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: json)
        } else if method != "GET" {
            req.httpBody = Data()
        }
        guard let result = try? await URLSession.shared.data(for: req) else { return nil }
        return (result.0, (result.1 as? HTTPURLResponse)?.statusCode ?? 0)
    }

    private struct SpImage: Decodable { let url: String }
    private struct Artist: Decodable { let name: String }
    private struct Album: Decodable { let images: [SpImage]? }
    private struct Track: Decodable { let name: String; let artists: [Artist]?; let album: Album? }
    private struct Current: Decodable { let is_playing: Bool; let item: Track? }
    private struct PlaylistItem: Decodable { let id: String; let name: String; let uri: String; let images: [SpImage]? }
    private struct PlaylistPage: Decodable { let items: [PlaylistItem?] }

    func refreshNowPlaying() async {
        guard isConnected, let response = await api("GET", "/me/player/currently-playing") else { return }
        guard response.1 == 200, let current = try? JSONDecoder().decode(Current.self, from: response.0), let item = current.item else {
            nowPlaying = nil
            return
        }
        nowPlaying = NowPlaying(title: item.name,
                                artist: item.artists?.map(\.name).joined(separator: ", ") ?? "",
                                isPlaying: current.is_playing,
                                artURL: item.album?.images?.first.flatMap { URL(string: $0.url) })
    }

    func loadPlaylists() async {
        guard isConnected, let response = await api("GET", "/me/playlists", query: [URLQueryItem(name: "limit", value: "50")]),
              response.1 == 200, let page = try? JSONDecoder().decode(PlaylistPage.self, from: response.0) else { return }
        playlists = page.items.compactMap { $0 }.map {
            Playlist(id: $0.id, name: $0.name, uri: $0.uri, imageURL: $0.images?.first.flatMap { URL(string: $0.url) })
        }
    }

    func togglePlay() async {
        let playing = nowPlaying?.isPlaying ?? false
        await control("PUT", playing ? "/me/player/pause" : "/me/player/play")
    }

    func next() async { await control("POST", "/me/player/next") }
    func previous() async { await control("POST", "/me/player/previous") }

    func play(uri: String) async {
        guard isConnected else {
            openInSpotify(uri)
            return
        }
        guard let status = await api("PUT", "/me/player/play", json: ["context_uri": uri])?.1 else { return }
        if status == 404 {
            // No active device: opening the app starts the playlist there.
            openInSpotify(uri)
        } else if status == 403 {
            message = "Spotify Premium is needed to control playback from Forge."
            openInSpotify(uri)
        }
        try? await Task.sleep(for: .milliseconds(700))
        await refreshNowPlaying()
    }

    private func control(_ method: String, _ path: String) async {
        guard let status = await api(method, path)?.1 else { return }
        switch status {
        case 404: message = "Open Spotify and start playing something first."
        case 403: message = "Spotify Premium is needed to control playback."
        default: message = nil
        }
        try? await Task.sleep(for: .milliseconds(500))
        await refreshNowPlaying()
    }

    /// Opens a playlist, album or track in the Spotify app. Accepts spotify: URIs or open.spotify.com links.
    func openInSpotify(_ link: String) {
        guard let uri = Self.spotifyURI(from: link), let url = URL(string: uri) else {
            if let url = URL(string: "spotify:") { UIApplication.shared.open(url) }
            return
        }
        UIApplication.shared.open(url)
    }

    static func spotifyURI(from link: String) -> String? {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("spotify:") { return trimmed }
        guard let url = URL(string: trimmed), url.host?.contains("spotify.com") == true else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" && !$0.hasPrefix("intl-") }
        guard parts.count >= 2 else { return nil }
        return "spotify:\(parts[0]):\(parts[1])"
    }

    // MARK: PKCE helpers

    private static func randomString(_ length: Int) -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        return String((0..<length).map { _ in chars.randomElement()! })
    }

    private static func challenge(for verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Minimal Keychain wrapper for the Spotify refresh token.
enum Keychain {
    private static func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "forge",
         kSecAttrAccount as String: key]
    }

    static func save(_ value: String, for key: String) {
        delete(key)
        var q = query(key)
        q[kSecValueData as String] = Data(value.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(q as CFDictionary, nil)
    }

    static func read(_ key: String) -> String? {
        var q = query(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        SecItemDelete(query(key) as CFDictionary)
    }
}
