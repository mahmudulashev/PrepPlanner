import SwiftUI
import SwiftData

@main
struct PrepPlannerApp: App {
    private let container: ModelContainer
    @State private var state: AppState

    init() {
        let container = Persistence.makeContainer()
        Seeder.seedIfNeeded(container.mainContext)
        self.container = container
        _state = State(initialValue: AppState(context: container.mainContext))
    }

    var body: some Scene {
        Window("PrepPlanner", id: "main") {
            RootView()
                .environment(state)
                .frame(minWidth: 1180, minHeight: 720)
        }
        .defaultSize(width: 1360, height: 880)
        .modelContainer(container)
        .commands { AppCommands(state: state) }

        Settings {
            SettingsView()
                .environment(state)
                .modelContainer(container)
        }
    }
}
