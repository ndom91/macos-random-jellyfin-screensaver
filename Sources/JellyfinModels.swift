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
    let type: String?
    let mediaType: String?
    let userData: JellyfinUserData?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case mediaType = "MediaType"
        case userData = "UserData"
    }
}

struct JellyfinUserData: Decodable {
    let played: Bool?

    enum CodingKeys: String, CodingKey {
        case played = "Played"
    }
}
