// Domain/Events/ActivitySnapshotEventPublisherProtocol.swift
import Foundation
import Combine

/// Protocol for publishing activity snapshot related events.
/// This acts as a secondary output port, allowing the domain to notify external components (e.g., ViewModels) of changes.
public protocol ActivitySnapshotEventPublisherProtocol {
    var publisher: AnyPublisher<ActivitySnapshotEvent, Never> { get }
    func publish(event: ActivitySnapshotEvent)
}
