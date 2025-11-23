// Infrastructure/Services/ActivitySnapshotEventPublisher.swift
import Foundation
import Combine

/// Concrete implementation of `ActivitySnapshotEventPublisherProtocol` using Combine's `PassthroughSubject`.
/// This lives in the Infrastructure layer as it uses Combine (an external framework).
final class ActivitySnapshotEventPublisher: ActivitySnapshotEventPublisherProtocol {
    private let _publisher = PassthroughSubject<ActivitySnapshotEvent, Never>()

    public var publisher: AnyPublisher<ActivitySnapshotEvent, Never> {
        _publisher.eraseToAnyPublisher()
    }

    public func publish(event: ActivitySnapshotEvent) {
        _publisher.send(event)
        print("ActivitySnapshotEventPublisher: Published event for user \(event.userID), date \(event.date).")
    }
}
