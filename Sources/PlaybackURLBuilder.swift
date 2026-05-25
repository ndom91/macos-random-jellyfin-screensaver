import Foundation

struct PlaybackURLBuilder {
    func candidateURLs(for item: JellyfinItem, settings: ScreensaverSettings) -> [URL] {
        [
            url(path: "/Videos/\(item.id)/stream.mp4", settings: settings, queryItems: [
                URLQueryItem(name: "static", value: "true"),
                URLQueryItem(name: "mediaSourceId", value: item.id),
                URLQueryItem(name: "api_key", value: settings.apiKey),
            ]),
            url(path: "/Videos/\(item.id)/stream", settings: settings, queryItems: [
                URLQueryItem(name: "static", value: "true"),
                URLQueryItem(name: "mediaSourceId", value: item.id),
                URLQueryItem(name: "api_key", value: settings.apiKey),
            ]),
            url(path: "/Videos/\(item.id)/master.m3u8", settings: settings, queryItems: [
                URLQueryItem(name: "mediaSourceId", value: item.id),
                URLQueryItem(name: "api_key", value: settings.apiKey),
            ]),
        ].compactMap { $0 }
    }

    private func url(path: String, settings: ScreensaverSettings, queryItems: [URLQueryItem]) -> URL? {
        guard var components = URLComponents(string: settings.baseURL) else {
            return nil
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpointPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + [basePath, endpointPath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        components.queryItems = queryItems
        return components.url
    }
}
