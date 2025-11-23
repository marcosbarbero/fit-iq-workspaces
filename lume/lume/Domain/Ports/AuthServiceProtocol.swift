import Foundation
import FitIQCore

protocol AuthServiceProtocol {
    func register(email: String, password: String, name: String, dateOfBirth: Date) async throws
        -> (User, AuthToken)
    func login(email: String, password: String) async throws -> AuthToken
    func refreshToken(_ token: String) async throws -> AuthToken
}
