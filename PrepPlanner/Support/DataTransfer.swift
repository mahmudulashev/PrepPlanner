import AppKit
import SwiftData
import UniformTypeIdentifiers

enum CSVKind {
    case ielts, sat, errors
}

/// Save/open panels and confirmations around backups and CSV export.
@MainActor
enum DataTransfer {
    static var backupsFolder: URL {
        Persistence.storeURL.deletingLastPathComponent().appending(path: "Backups", directoryHint: .isDirectory)
    }

    private static func stamp(_ format: String = "yyyy-MM-dd") -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f.string(from: Date())
    }

    static func exportBackup(context: ModelContext) {
        do {
            try context.save()
            let data = try Backup(context: context).encoded()
            save(data, name: "PrepPlanner Backup \(stamp()).json", type: .json)
        } catch {
            showError(String(localized: "Couldn’t create the backup."), error)
        }
    }

    /// Returns true when data was replaced.
    @discardableResult
    static func importBackup(context: ModelContext) -> Bool {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "Choose a PrepPlanner backup file")
        guard panel.runModal() == .OK, let url = panel.url else { return false }

        let backup: Backup
        do {
            backup = try Backup.decode(Data(contentsOf: url))
        } catch {
            showError(String(localized: "This file isn’t a PrepPlanner backup."), error)
            return false
        }

        let alert = NSAlert()
        alert.messageText = String(localized: "Replace all data with this backup?")
        let date = backup.exportedAt.formatted(date: .long, time: .shortened)
        alert.informativeText = String(localized: "Backup from \(date): \(backup.blocks.count) blocks, \(backup.ieltsMocks.count + backup.satMocks.count) mocks, \(backup.errors.count) errors, \(backup.habits.count) habits. Your current data is saved to the Backups folder first.")
        alert.addButton(withTitle: String(localized: "Replace"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return false }

        do {
            // Safety copy of the current data before replacing it.
            try context.save()
            let current = try Backup(context: context).encoded()
            try FileManager.default.createDirectory(at: backupsFolder, withIntermediateDirectories: true)
            try current.write(to: backupsFolder.appending(path: "Before import \(stamp("yyyy-MM-dd HHmmss")).json"))
            try backup.restore(into: context)
            return true
        } catch {
            showError(String(localized: "Couldn’t restore the backup."), error)
            return false
        }
    }

    static func exportCSV(_ kind: CSVKind, context: ModelContext) {
        let text: String
        let name: String
        switch kind {
        case .ielts:
            text = CSVExport.ielts((try? context.fetch(FetchDescriptor<IELTSMock>())) ?? [])
            name = "IELTS results \(stamp()).csv"
        case .sat:
            text = CSVExport.sat((try? context.fetch(FetchDescriptor<SATMock>())) ?? [])
            name = "SAT results \(stamp()).csv"
        case .errors:
            text = CSVExport.errors((try? context.fetch(FetchDescriptor<ErrorEntry>())) ?? [])
            name = "Error log \(stamp()).csv"
        }
        save(Data(text.utf8), name: name, type: .commaSeparatedText)
    }

    static func showBackupsFolder() {
        try? FileManager.default.createDirectory(at: backupsFolder, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([backupsFolder])
    }

    private static func save(_ data: Data, name: String, type: UTType) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = name
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            showError(String(localized: "Couldn’t save the file."), error)
        }
    }

    private static func showError(_ message: String, _ error: Error) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}
