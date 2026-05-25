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
    let userData: JellyfinUserData?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case container = "Container"
        case type = "Type"
        case mediaType = "MediaType"
        case userData = "UserData"
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

struct JellyfinUserData: Decodable {
    let played: Bool?

    enum CodingKeys: String, CodingKey {
        case played = "Played"
    }
}
