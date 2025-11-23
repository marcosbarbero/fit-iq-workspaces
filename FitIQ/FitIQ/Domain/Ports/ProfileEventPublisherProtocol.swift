//
//  ProfileEventPublisherProtocol.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Combine
import Foundation

/// Protocol for publishing profile-related events.
/// This acts as a secondary output port, allowing the domain to notify external components
/// (e.g., ViewModels, sync services) of profile changes.
public protocol ProfileEventPublisherProtocol {
    /// Publisher stream for profile events
    var publisher: AnyPublisher<ProfileEvent, Never> { get }

    /// Publish a profile event
    /// - Parameter event: The profile event to publish
    func publish(event: ProfileEvent)
}
