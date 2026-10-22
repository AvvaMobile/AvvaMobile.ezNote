import Foundation

/// Tüm sekmelere uygulanan yazı tipi. `family == nil` sistemin eş aralıklı fontu demek.
public struct FontSettings: Equatable {
    public static let defaultSize = 14.0
    public static let minSize = 8.0
    public static let maxSize = 72.0

    public var family: String?
    public var size: Double

    public init(family: String?, size: Double) {
        self.family = family
        self.size = size
    }

    public func zoomedIn() -> FontSettings { resized(size + 1) }
    public func zoomedOut() -> FontSettings { resized(size - 1) }

    private func resized(_ newSize: Double) -> FontSettings {
        FontSettings(family: family, size: min(max(newSize, Self.minSize), Self.maxSize))
    }
}

public struct FontSettingsStore {
    private let defaults: UserDefaults
    private let familyKey = "fontFamily"
    private let sizeKey = "fontSize"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> FontSettings {
        let size = defaults.double(forKey: sizeKey)
        return FontSettings(family: defaults.string(forKey: familyKey), size: size > 0 ? size : FontSettings.defaultSize)
    }

    public func save(_ settings: FontSettings) {
        defaults.set(settings.family, forKey: familyKey)
        defaults.set(settings.size, forKey: sizeKey)
    }
}
