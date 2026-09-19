import AppKit

/// In-app language choice. Stored as this app's AppleLanguages/AppleLocale defaults; applies after a restart.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english, uzbek

    var id: String { rawValue }

    private static let languagesKey = "AppleLanguages"
    private static let localeKey = "AppleLocale"

    static var current: AppLanguage {
        let domain = Bundle.main.bundleIdentifier.flatMap { UserDefaults.standard.persistentDomain(forName: $0) }
        switch (domain?[languagesKey] as? [String])?.first {
        case "uz": return .uzbek
        case "en": return .english
        default: return .system
        }
    }

    /// Whether the running app is showing its Uzbek localization.
    static var isUzbekActive: Bool {
        Bundle.main.preferredLocalizations.first?.hasPrefix("uz") == true
    }

    func apply() {
        let defaults = UserDefaults.standard
        switch self {
        case .system:
            defaults.removeObject(forKey: Self.languagesKey)
            defaults.removeObject(forKey: Self.localeKey)
        case .english:
            defaults.set(["en"], forKey: Self.languagesKey)
            defaults.removeObject(forKey: Self.localeKey)
        case .uzbek:
            defaults.set(["uz"], forKey: Self.languagesKey)
            // Also switch date and number formats (month and weekday names).
            defaults.set("uz_UZ", forKey: Self.localeKey)
        }
    }

    static func relaunch() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", path]
        try? task.run()
        NSApp.terminate(nil)
    }
}
