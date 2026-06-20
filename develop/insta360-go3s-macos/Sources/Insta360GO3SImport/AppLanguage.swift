import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system
    case chinese = "zh"
    case english = "en"

    var id: String { rawValue }

    private static let userDefaultsKey = "insta360.appLanguage"

    /// Menu / picker label (always shown in that language).
    var displayName: String {
        switch self {
        case .system:
            return L10n.pickDirect(isChinese: resolvesToChinese(), zh: "跟随系统", en: "Follow System")
        case .chinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }

    static func load() -> AppLanguage {
        guard let raw = UserDefaults.standard.string(forKey: userDefaultsKey),
              let value = AppLanguage(rawValue: raw) else {
            return .system
        }
        return value
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: Self.userDefaultsKey)
    }

    func resolvesToChinese() -> Bool {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? Locale.current.identifier
            return preferred.hasPrefix("zh")
        case .chinese:
            return true
        case .english:
            return false
        }
    }

    func apiLanguageCode() -> String {
        resolvesToChinese() ? "zh" : "en"
    }

    var resolvedLocale: Locale {
        resolvesToChinese() ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
    }
}
