//
//  URLSessionNetworkClient.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

import Foundation

final class URLSessionNetworkClient: NetworkClientProtocol {
    func executeRequest(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        return (data, httpResponse)
    }
    
    
}
