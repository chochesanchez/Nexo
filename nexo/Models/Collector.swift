import Foundation

struct Collector: Codable, Identifiable {
    let id: UUID
    let displayName: String
    let accepts: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case accepts
    }
}
