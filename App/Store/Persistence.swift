import Foundation
import AboutHerCore

/// Reads and writes the single JSON file that holds everything, and keeps daily copies of it.
struct Persistence {
    let directory: URL

    var fileURL: URL { directory.appending(path: "about-her.json") }
    var backupDirectory: URL { directory.appending(path: "Kopie", directoryHint: .isDirectory) }

    static func live() -> Persistence {
        let fileManager = FileManager.default
        let base = (try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                         appropriateFor: nil, create: true))
            ?? fileManager.temporaryDirectory
        let directory = base.appending(path: "AboutHer", directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return Persistence(directory: directory)
    }

    /// The saved file as it is on disk, or `nil` when there is none yet (the very first launch).
    /// Throws when the file exists but can't be read right now, e.g. while the phone is still
    /// locked after a restart.
    func readSavedFile() throws -> Data? {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return nil }
        return try Data(contentsOf: fileURL)
    }

    func save(_ appData: AppData) throws {
        let encoded = try AppDataCoding.encode(appData)
        try encoded.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// One copy per day; the newest 14 are kept.
    func makeDailyBackup(today: LocalDate) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return }
        try? fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        let target = backupDirectory.appending(path: "about-her-\(today.iso).json")
        if !fileManager.fileExists(atPath: target.path(percentEncoded: false)) {
            try? fileManager.copyItem(at: fileURL, to: target)
        }
        let backups = (try? fileManager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: nil)) ?? []
        let newestFirst = backups
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for old in newestFirst.dropFirst(14) {
            try? fileManager.removeItem(at: old)
        }
    }

    /// Whether there are any daily copies at all, readable or not.
    var hasBackupFiles: Bool {
        let files = (try? FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: nil)) ?? []
        return files.contains { $0.pathExtension == "json" }
    }

    /// The newest daily copy that can still be read, with the day it was made.
    func newestReadableBackup() -> (data: AppData, day: LocalDate)? {
        let files = (try? FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: nil)) ?? []
        let newestFirst = files
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for url in newestFirst {
            let name = url.deletingPathExtension().lastPathComponent     // about-her-2026-11-09
            guard let day = LocalDate(iso: String(name.suffix(10))),
                  let raw = try? Data(contentsOf: url),
                  !AppDataCoding.isFromNewerVersion(raw),
                  let backup = try? AppDataCoding.decode(raw)
            else { continue }
            return (backup, day)
        }
        return nil
    }

    /// Moves an unreadable file aside (or at least copies it), so nothing ever overwrites her history.
    /// Returns `false` when the file could be neither moved nor copied.
    @discardableResult
    func setAsideDamagedFile() -> Bool {
        let fileManager = FileManager.default
        let stamp = Int(Date().timeIntervalSince1970)
        let target = directory.appending(path: "about-her-uszkodzony-\(stamp).json")
        if (try? fileManager.moveItem(at: fileURL, to: target)) != nil {
            return true
        }
        return (try? fileManager.copyItem(at: fileURL, to: target)) != nil
    }
}
