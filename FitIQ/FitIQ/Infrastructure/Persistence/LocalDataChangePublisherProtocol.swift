// Domain/Events/LocalDataChangePublisherProtocol.swift
import Foundation
import Combine

/// Protocol for publishing events when local data changes that require remote synchronization.
public protocol LocalDataChangePublisherProtocol {
    var publisher: AnyPublisher<LocalDataNeedsSyncEvent, Never> { get }
    func publish(event: LocalDataNeedsSyncEvent)
}
