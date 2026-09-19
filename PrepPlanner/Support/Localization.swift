import Foundation

extension String {
    /// Localized string with automatic grammar agreement, e.g. `^[\(count) block](inflect: true)`.
    static func inflected(_ value: String.LocalizationValue) -> String {
        String(AttributedString(localized: value).characters)
    }
}
