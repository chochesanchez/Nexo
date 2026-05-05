import Foundation

struct NewProfile: Encodable {
    let userId: UUID
    let nombre: String
    let apellido: String
    let telefono: String
    let correo: String
    let edad: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case nombre, apellido, telefono, correo, edad
    }
}
