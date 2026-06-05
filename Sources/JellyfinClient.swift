import Foundation

final class JellyfinClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    func fetchRandomItems(settings: ScreensaverSettings) async throws -> [JellyfinItem] {
        let url = try randomItemsURL(settings: settings)

        var request = URLRequest(url: url)
        request.setValue(settings.apiKey, forHTTPHeaderField: "X-Emby-Token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JellyfinClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw JellyfinClientError.httpStatus(httpResponse.statusCode, url)
        }

        return try decoder.decode(JellyfinItemsResponse.self, from: data).items
    }

    func redactedRandomItemsURL(settings: ScreensaverSettings) -> String {
        do {
            return try randomItemsURL(settings: settings).absoluteString
        } catch {
            return "<invalid URL>"
        }
    }

    func fetchSubtitleCues(item: JellyfinItem, settings: ScreensaverSettings) async throws -> [SubtitleCue] {
        guard let subtitleStream = item.mediaStreams?.first(where: { $0.type == "Subtitle" }),
              let subtitleIndex = subtitleStream.index else {
            return []
        }

        guard var components = URLComponents(string: settings.baseURL) else {
            throw JellyfinClientError.invalidURL
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpointPath = "Videos/\(item.id)/\(item.id)/Subtitles/\(subtitleIndex)/Stream.srt"
        components.path = "/" + [basePath, endpointPath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        components.queryItems = [URLQueryItem(name: "api_key", value: settings.apiKey)]

        guard let url = components.url else {
            throw JellyfinClientError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw JellyfinClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw JellyfinClientError.httpStatus(httpResponse.statusCode, url)
        }
        guard let content = String(data: data, encoding: .utf8) else {
            return []
        }

        return SubtitleParser.parseSRT(content)
    }

    private func randomItemsURL(settings: ScreensaverSettings) throws -> URL {
        guard var components = URLComponents(string: settings.baseURL) else {
            throw JellyfinClientError.invalidURL
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpointPath = "Users/\(settings.userID)/Items"
        components.path = "/" + [basePath, endpointPath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")

        components.queryItems = [
            URLQueryItem(name: "IncludeItemTypes", value: settings.mediaType.jellyfinIncludeItemType),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "SortBy", value: "Random"),
            URLQueryItem(name: "Limit", value: "100"),
            URLQueryItem(name: "Fields", value: "ExternalUrls,MediaSources,MediaStreams,RunTimeTicks"),
        ]

        guard let url = components.url else {
            throw JellyfinClientError.invalidURL
        }
        return url
    }
}

enum JellyfinClientError: Error, CustomStringConvertible {
    case invalidURL
    case invalidResponse
    case httpStatus(Int, URL)

    var description: String {
        switch self {
        case .invalidURL:
            return "Invalid Jellyfin URL"
        case .invalidResponse:
            return "Invalid Jellyfin response"
        case .httpStatus(let statusCode, let url):
            return "Jellyfin request failed with HTTP status \(statusCode): \(url.absoluteString)"
        }
    }
}
