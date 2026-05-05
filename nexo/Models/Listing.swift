import Foundation

struct Listing: Codable, Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let material: String
    let quantityLabel: String?
    let notes: String?
    let lat: Double
    let lng: Double
    let status: String
    let claimedBy: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt     = "created_at"
        case material
        case quantityLabel = "quantity_label"
        case notes
        case lat, lng, status
        case claimedBy     = "claimed_by"
    }
}

struct NewListing: Encodable {
    let material: String
    let quantityLabel: String?
    let notes: String?
    let lat: Double
    let lng: Double

    enum CodingKeys: String, CodingKey {
        case material
        case quantityLabel = "quantity_label"
        case notes
        case lat, lng
    }
}
