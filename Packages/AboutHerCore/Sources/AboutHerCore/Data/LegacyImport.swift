import Foundation

/// Reads backups saved by the old web version (about-her.html → ustawienia → "zapisz kopię").
///
/// The backup looks like `{"data": {"periodDays": {"2025-03-14": true, …}, …}, "photos": […]}`.
/// For now only the period history is taken over; the rest follows with the matching screens.
public enum LegacyImport {
    public enum ImportError: Error, Equatable {
        case notAnAboutHerBackup
    }

    private struct Backup: Decodable {
        let data: Payload
    }

    private struct Payload: Decodable {
        let periodDays: [String: Bool]?
    }

    public static func periodDays(fromHTMLExport raw: Data) throws -> Set<LocalDate> {
        let backup: Backup
        do {
            backup = try JSONDecoder().decode(Backup.self, from: raw)
        } catch {
            throw ImportError.notAnAboutHerBackup
        }
        var result = Set<LocalDate>()
        for (key, isMarked) in backup.data.periodDays ?? [:] where isMarked {
            if let date = LocalDate(iso: key) {
                result.insert(date)
            }
        }
        return result
    }
}
