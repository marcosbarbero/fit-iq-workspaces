import Foundation
import HealthKit
import BackgroundTasks

protocol BackgroundSyncManagerProtocol {
    func registerBackgroundTasks()
    func startHealthKitObservations() async throws
}
