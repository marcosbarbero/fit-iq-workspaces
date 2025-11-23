import Foundation
import FitIQCore

protocol TokenStorageProtocol {
    func saveToken(_ token: AuthToken) async throws
    func getToken() async throws -> AuthToken?
    func deleteToken() async throws
}
