//
//  ProfileEventPublisher.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Combine
import Foundation

/// Concrete implementation of ProfileEventPublisherProtocol
/// Publishes profile-related domain events to interested subscribers
final class ProfileEventPublisher: ProfileEventPublisherProtocol {

    // MARK: - Properties

    private let _publisher = PassthroughSubject<ProfileEvent, Never>()

    public var publisher: AnyPublisher<ProfileEvent, Never> {
        _publisher.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    init() {
        print("ProfileEventPublisher: Initialized")
    }

    // MARK: - Public Methods

    public func publish(event: ProfileEvent) {
        _publisher.send(event)
        print("ProfileEventPublisher: Published event - \(event)")
    }
}
