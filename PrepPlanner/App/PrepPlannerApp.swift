import SwiftUI
import SwiftData

@main
struct PrepPlannerApp: App {
    private let container: ModelContainer
    @State private var state: AppState
    @State private var tracker: NowTracker
    @AppStorage(MenuBarPreference.key) private var showMenuBar = true

    init() {
        let container = Persistence.makeContainer()
        Seeder.seedIfNeeded(container.mainContext)
        self.container = container
        _state = State(initialValue: AppState(context: container.mainContext))
        _tracker = State(initialValue: NowTracker(context: container.mainContext))
    }

    var body: some Scene {
        Window("PrepPlanner", id: "main") {
            RootView()
                .environment(state)
                .task { NotificationScheduler.shared.start(container: container) }
                .frame(minWidth: 860, minHeight: 600)
        }
        .defaultSize(width: 1360, height: 880)
        .windowResizability(.contentMinSize)
        .modelContainer(container)
        .commands { AppCommands(state: state) }

        Settings {
            SettingsView()
                .environment(state)
                .modelContainer(container)
        }

        MenuBarExtra(isInserted: $showMenuBar) {
            MenuBarPanel(tracker: tracker)
                .modelContainer(container)
        } label: {
            MenuBarLabel(tracker: tracker)
        }
        .menuBarExtraStyle(.window)
    }
}

enum MenuBarPreference {
    static let key = "showMenuBarExtra"
}
