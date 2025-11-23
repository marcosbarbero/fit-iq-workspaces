//
//  NetworkClientProtocol.swift
//  FitIQCore
//
//  Created by FitIQ Team
//

import Foundation

/// Protocol defining the contract for executing network requests.
/// This is the foundational networking abstraction used throughout FitIQCore.
public protocol NetworkClientProtocol: Sendable {
    /// Executes a network request and returns the response data and HTTP response
    /// - Parameter request: The URLRequest to execute
    /// - Returns: A tuple containing the response data and HTTPURLResponse
    /// - Throws: APIError if the request fails
    func executeRequest(request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
