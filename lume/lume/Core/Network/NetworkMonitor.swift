//
//  NetworkMonitor.swift
//  lume
//
//  Created by AI Assistant on 16/01/2025.
//

import Combine
import Foundation
import Network

/// Monitors network connectivity status
/// Used to determine when to attempt online operations vs offline-first behavior
@MainActor
final class NetworkMonitor: ObservableObject {

    // MARK: - Singleton

    static let shared = NetworkMonitor()

    // MARK: - Published Properties

    @Published private(set) var isConnected: Bool = false
    @Published private(set) var connectionType: ConnectionType = .unknown

    // MARK: - Private Properties

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.lume.networkMonitor")

    // MARK: - Types

    enum ConnectionType {
        case wifi
        case cellular
        case wiredEthernet
        case unknown
    }

    // MARK: - Initialization

    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }

    // MARK: - Public Methods

    /// Start monitoring network status
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let pathStatus = path.status
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isConnected = (pathStatus == .satisfied)
            }
        }
        monitor.start(queue: queue)
        print("🌐 [NetworkMonitor] Started monitoring network connectivity")
    }

    /// Stop monitoring network status
    func stopMonitoring() {
        monitor.cancel()
        print("🌐 [NetworkMonitor] Stopped monitoring network connectivity")
    }

    // MARK: - Private Methods

    private func updateConnectionStatus(path: NWPath) {
        isConnected = path.status == .satisfied

        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wiredEthernet
        } else {
            connectionType = .unknown
        }

        let connectionStatus = isConnected ? "connected" : "disconnected"
        let typeDescription: String

        switch connectionType {
        case .wifi:
            typeDescription = "WiFi"
        case .cellular:
            typeDescription = "Cellular"
        case .wiredEthernet:
            typeDescription = "Ethernet"
        case .unknown:
            typeDescription = "Unknown"
        }

        print("🌐 [NetworkMonitor] Network status: \(connectionStatus) via \(typeDescription)")
    }

    deinit {
        monitor.cancel()
    }
}
