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

    /// `nil` on the very first launch.
    func load() throws -> AppData? {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return nil }
        let raw = try Data(contentsOf: fileURL)
        return try AppDataCoding.decode(raw)
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

    /// Moves an unreadable file aside, so nothing ever overwrites her history.
    func setAsideDamagedFile() {
        let stamp = Int(Date().timeIntervalSince1970)
        let target = directory.appending(path: "about-her-uszkodzony-\(stamp).json")
        try? FileManager.default.moveItem(at: fileURL, to: target)
    }
}
