//
//  NetworkClientProtocol.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

import Foundation

// 📐 The New Networking Dependency (Infrastructure/Network/NetworkClientProtocol.swift)
protocol NetworkClientProtocol {
    func executeRequest(request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
