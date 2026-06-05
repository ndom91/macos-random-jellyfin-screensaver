import Foundation

struct JellyfinItemsResponse: Decodable {
    let items: [JellyfinItem]

    enum CodingKeys: String, CodingKey {
        case items = "Items"
    }
}

struct JellyfinItem: Decodable {
    let id: String
    let name: String?
    let container: String?
    let type: String?
    let mediaType: String?
    let mediaStreams: [JellyfinMediaStream]?
    let userData: JellyfinUserData?
    let runTimeTicks: Int64?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case container = "Container"
        case type = "Type"
        case mediaType = "MediaType"
        case mediaStreams = "MediaStreams"
        case userData = "UserData"
        case runTimeTicks = "RunTimeTicks"
    }

    var runTimeSeconds: TimeInterval? {
        runTimeTicks.map { TimeInterval($0) / 10_000_000 }
    }

    var isLikelyAVPlayerCompatible: Bool {
        guard let container else {
            return false
        }

        let compatibleContainers = ["mp4", "mov", "m4a", "m4v"]
        return container
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .contains { compatibleContainers.contains($0) }
    }
}

struct JellyfinMediaStream: Decodable {
    let index: Int?
    let type: String?
    let title: String?
    let displayTitle: String?
    let language: String?
    let codec: String?
    let path: String?

    enum CodingKeys: String, CodingKey {
        case index = "Index"
        case type = "Type"
        case title = "Title"
        case displayTitle = "DisplayTitle"
        case language = "Language"
        case codec = "Codec"
        case path = "Path"
    }

}

struct JellyfinUserData: Decodable {
    let played: Bool?

    enum CodingKeys: String, CodingKey {
        case played = "Played"
    }
}
