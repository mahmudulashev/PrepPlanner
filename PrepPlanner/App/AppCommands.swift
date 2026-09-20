import SwiftUI

struct AppCommands: Commands {
    let state: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Block") { state.newBlockAtNextFreeSlot() }
                .keyboardShortcut("n")
            Divider()
            Button("Log Error…") { state.editor = .error(nil, nil) }
                .keyboardShortcut("e")
            Button("New IELTS Mock…") {
                state.resultsTab = .ielts
                state.editor = .ielts(nil)
            }
            .keyboardShortcut("r")
            Button("New SAT Mock…") {
                state.resultsTab = .sat
                state.editor = .sat(nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            Button("New Habit…") {
                state.section = .habits
                state.editor = .habit(nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .option])
        }
        CommandGroup(replacing: .importExport) {
            Button("Export Backup…") { state.exportBackup() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            Button("Import Backup…") { state.importBackup() }
            Divider()
            Button("Export IELTS Results as CSV…") { state.exportCSV(.ielts) }
            Button("Export SAT Results as CSV…") { state.exportCSV(.sat) }
            Button("Export Error Log as CSV…") { state.exportCSV(.errors) }
        }
        CommandGroup(replacing: .saveItem) {}
        CommandGroup(replacing: .printItem) {}

        CommandGroup(after: .sidebar) {
            Button(state.showInspector ? "Hide Inspector" : "Show Inspector") {
                state.showInspector.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            Divider()
        }

        CommandMenu("Go") {
            ForEach(SidebarSection.allCases) { section in
                Button(section.title) { state.section = section }
                    .keyboardShortcut(section.shortcut)
            }
            Divider()
            Button("Today") { state.goToday() }
                .keyboardShortcut("t")
            Button("Previous Day") { state.shiftDay(-1) }
                .keyboardShortcut("[")
            Button("Next Day") { state.shiftDay(1) }
                .keyboardShortcut("]")
        }

        CommandMenu("Block") {
            Button("Mark Done") { state.setStatus(.done) }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Button("Mark Partial") { state.setStatus(.partial) }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            Button("Mark Skipped") { state.setStatus(.skipped) }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            Button("Reset to Planned") { state.setStatus(.planned) }
            Divider()
            Button("Duplicate Block") { state.duplicateSelected() }
                .keyboardShortcut("d")
            Button("Delete Block") { state.deleteSelected() }
            Divider()
            Button("Save Day as Template…") {
                state.section = .planner
                state.showSaveTemplate = true
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            Button("Apply Template…") {
                state.section = .planner
                state.showApplyTemplate = true
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
        }
    }
}
