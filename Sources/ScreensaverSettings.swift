import Foundation
import ScreenSaver

enum MediaType: String, CaseIterable {
    case movies
    case tvEpisodes

    var displayName: String {
        switch self {
        case .movies:
            return "Movies"
        case .tvEpisodes:
            return "TV Episodes"
        }
    }

    var jellyfinIncludeItemType: String {
        switch self {
        case .movies:
            return "Movie"
        case .tvEpisodes:
            return "Episode"
        }
    }
}

struct ScreensaverSettings {
    static let moduleName = "JellyfinRandomMovieScreensaver"

    var baseURL: String
    var apiKey: String
    var userID: String
    var mediaType: MediaType
    var muted: Bool

    var hasRequiredPlaybackSettings: Bool {
        !baseURL.isEmpty && !apiKey.isEmpty && !userID.isEmpty
    }

    static var defaults: ScreenSaverDefaults {
        guard let defaults = ScreenSaverDefaults(forModuleWithName: moduleName) else {
            fatalError("Unable to create ScreenSaverDefaults for \(moduleName)")
        }

        defaults.register(defaults: [
            Keys.baseURL: "",
            Keys.apiKey: "",
            Keys.userID: "",
            Keys.mediaType: MediaType.movies.rawValue,
            Keys.muted: true,
        ])

        return defaults
    }

    static func load() -> ScreensaverSettings {
        let defaults = defaults
        let mediaTypeValue = defaults.string(forKey: Keys.mediaType) ?? MediaType.movies.rawValue

        return ScreensaverSettings(
            baseURL: defaults.string(forKey: Keys.baseURL) ?? "",
            apiKey: defaults.string(forKey: Keys.apiKey) ?? "",
            userID: defaults.string(forKey: Keys.userID) ?? "",
            mediaType: MediaType(rawValue: mediaTypeValue) ?? .movies,
            muted: defaults.object(forKey: Keys.muted) as? Bool ?? true
        )
    }

    func save() {
        let defaults = ScreensaverSettings.defaults
        defaults.set(Self.normalizedBaseURL(baseURL), forKey: Keys.baseURL)
        defaults.set(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.apiKey)
        defaults.set(userID.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.userID)
        defaults.set(mediaType.rawValue, forKey: Keys.mediaType)
        defaults.set(muted, forKey: Keys.muted)
        defaults.synchronize()
    }

    static func normalizedBaseURL(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if let components = URLComponents(string: trimmed), let scheme = components.scheme, let host = components.host {
            var baseComponents = URLComponents()
            baseComponents.scheme = scheme
            baseComponents.host = host
            baseComponents.port = components.port

            let pathSegments = components.path
                .split(separator: "/")
                .map(String.init)

            if let firstSegment = pathSegments.first,
               !["Users", "Items", "Videos", "web"].contains(firstSegment) {
                baseComponents.path = "/\(firstSegment)"
            }

            return baseComponents.url?.absoluteString ?? trimmed
        }

        var normalized = trimmed
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return normalized
    }

    private enum Keys {
        static let baseURL = "baseURL"
        static let apiKey = "apiKey"
        static let userID = "userID"
        static let mediaType = "mediaType"
        static let muted = "muted"
    }
}
