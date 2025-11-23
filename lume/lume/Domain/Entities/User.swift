import Foundation

struct User: Identifiable, Codable, Equatable {
    let id: UUID
    let email: String
    let name: String
    let dateOfBirth: Date
    let createdAt: Date

    init(id: UUID, email: String, name: String, dateOfBirth: Date, createdAt: Date) {
        self.id = id
        self.email = email
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.createdAt = createdAt
    }
}
