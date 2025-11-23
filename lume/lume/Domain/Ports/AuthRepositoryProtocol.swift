import Foundation
import FitIQCore

protocol AuthRepositoryProtocol {
    func register(email: String, password: String, name: String, dateOfBirth: Date) async throws
        -> User
    func login(email: String, password: String) async throws -> AuthToken
    func refreshToken() async throws -> AuthToken
    func logout() async throws
}
