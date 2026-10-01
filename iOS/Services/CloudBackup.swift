import Foundation

/// Keeps a copy of all app data in a folder the user picks in iCloud Drive.
/// Uses a bookmark to the folder, so it works with a free Apple ID (no CloudKit entitlement needed).
@MainActor
final class CloudBackup: ObservableObject {
    @Published private(set) var folderName: String?
    @Published private(set) var lastBackup: Date?
    @Published var lastError: String?
    /// True when the chosen folder already holds a backup and the user hasn't chosen
    /// between restoring it and overwriting it. Writes are paused until then.
    @Published var awaitingRestoreDecision = false

    static let fileName = "Forge-data.json"
    private let bookmarkKey = "forge.backupFolderBookmark"
    private let lastBackupKey = "forge.lastBackup"
    private var pending: Task<Void, Never>?

    init() {
        lastBackup = UserDefaults.standard.object(forKey: lastBackupKey) as? Date
        folderName = resolveFolder()?.lastPathComponent
    }

    var isConfigured: Bool { folderName != nil }

    func setFolder(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: bookmarkKey)
            folderName = url.lastPathComponent
            lastError = nil
            awaitingRestoreDecision = FileManager.default.fileExists(atPath: url.appendingPathComponent(Self.fileName).path)
                || FileManager.default.fileExists(atPath: url.appendingPathComponent("." + Self.fileName + ".icloud").path)
        } catch {
            lastError = "Couldn't remember that folder: \(error.localizedDescription)"
        }
    }

    func disconnect() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        folderName = nil
    }

    private func resolveFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        if stale, let fresh = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(fresh, forKey: bookmarkKey)
        }
        return url
    }

    /// Debounced so rapid edits (typing a weight) produce one write.
    func scheduleBackup(_ data: Data) {
        guard isConfigured, !awaitingRestoreDecision else { return }
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.writeNow(data)
        }
    }

    func writeNow(_ data: Data) {
        guard !awaitingRestoreDecision, let folder = resolveFolder() else { return }
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        let target = folder.appendingPathComponent(Self.fileName)
        var coordError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: target, options: .forReplacing, error: &coordError) { url in
            do { try data.write(to: url, options: .atomic) } catch { writeError = error }
        }
        if let e = writeError ?? (coordError as Error?) {
            lastError = "iCloud Drive backup failed: \(e.localizedDescription)"
        } else {
            lastError = nil
            lastBackup = Date()
            UserDefaults.standard.set(lastBackup, forKey: lastBackupKey)
        }
    }

    func readBackup() -> Data? {
        guard let folder = resolveFolder() else {
            lastError = "Choose your iCloud Drive folder first."
            return nil
        }
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        let target = folder.appendingPathComponent(Self.fileName)
        try? FileManager.default.startDownloadingUbiquitousItem(at: target)
        var coordError: NSError?
        var result: Data?
        NSFileCoordinator().coordinate(readingItemAt: target, options: [], error: &coordError) { url in
            result = try? Data(contentsOf: url)
        }
        if result != nil { awaitingRestoreDecision = false }
        if result == nil {
            lastError = "No backup found in \(folder.lastPathComponent). If it was just synced, wait a moment and try again."
        }
        return result
    }
}
