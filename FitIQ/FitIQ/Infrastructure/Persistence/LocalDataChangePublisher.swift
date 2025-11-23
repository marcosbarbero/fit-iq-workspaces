// Infrastructure/Services/LocalDataChangePublisher.swift
import Foundation
import Combine

/// Concrete implementation of `LocalDataChangePublisherProtocol` using Combine's `PassthroughSubject`.
/// This lives in the Infrastructure layer as it uses Combine.
final class LocalDataChangePublisher: LocalDataChangePublisherProtocol {
    private let _publisher = PassthroughSubject<LocalDataNeedsSyncEvent, Never>()

    public var publisher: AnyPublisher<LocalDataNeedsSyncEvent, Never> {
        _publisher.eraseToAnyPublisher()
    }

    public func publish(event: LocalDataNeedsSyncEvent) {
        _publisher.send(event)
        print("LocalDataChangePublisher: Published event for \(event.modelType) localID \(event.localID), user \(event.userID). IsNew: \(event.isNewRecord)")
    }
}
