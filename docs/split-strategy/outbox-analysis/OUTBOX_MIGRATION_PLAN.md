# Outbox Pattern Migration to FitIQCore - Implementation Plan

**Date:** 2025-01-27  
**Status:** Ready for Implementation  
**Priority:** High  
**Estimated Effort:** 12-16 hours total

---

## Overview

This document provides a step-by-step implementation plan for migrating the Outbox Pattern from FitIQ and Lume to a unified FitIQCore implementation.

**Goals:**
- Create robust, reusable Outbox Pattern in FitIQCore
- Migrate FitIQ with minimal changes (low-risk)
- Migrate Lume with schema upgrade (medium-risk)
- Eliminate 500+ lines of duplicated code
- Improve reliability and observability

---

## Phase 1: FitIQCore Foundation (4-5 hours)

### Step 1.1: Create Domain Models

**File:** `FitIQCore/Sources/FitIQCore/Sync/Domain/OutboxEvent.swift`

```swift
import Foundation

/// Domain model for Outbox Pattern events
/// Represents a pending synchronization operation
public struct OutboxEvent: Identifiable, Codable, Sendable {
    public let id: UUID
    public let eventType: OutboxEventType
    public let entityID: UUID
    public let userID: String
    public var status: OutboxEventStatus
    public let createdAt: Date
    public var lastAttemptAt: Date?
    public var attemptCount: Int
    public let maxAttempts: Int
    public var errorMessage: String?
    public var completedAt: Date?
    public var metadata: OutboxMetadata?
    public let priority: Int
    public let isNewRecord: Bool
    
    public init(
        id: UUID = UUID(),
        eventType: OutboxEventType,
        entityID: UUID,
        userID: String,
        status: OutboxEventStatus = .pending,
        createdAt: Date = Date(),
        lastAttemptAt: Date? = nil,
        attemptCount: Int = 0,
        maxAttempts: Int = 5,
        errorMessage: String? = nil,
        completedAt: Date? = nil,
        metadata: OutboxMetadata? = nil,
        priority: Int = 0,
        isNewRecord: Bool = true
    ) {
        self.id = id
        self.eventType = eventType
        self.entityID = entityID
        self.userID = userID
        self.status = status
        self.createdAt = createdAt
        self.lastAttemptAt = lastAttemptAt
        self.attemptCount = attemptCount
        self.maxAttempts = maxAttempts
        self.errorMessage = errorMessage
        self.completedAt = completedAt
        self.metadata = metadata
        self.priority = priority
        self.isNewRecord = isNewRecord
    }
}

/// Type-safe event types for Outbox Pattern
public enum OutboxEventType: String, Codable, CaseIterable, Sendable {
    // FitIQ events
    case progressEntry = "progressEntry"
    case physicalAttribute = "physicalAttribute"
    case activitySnapshot = "activitySnapshot"
    case profileMetadata = "profileMetadata"
    case profilePhysical = "profilePhysical"
    case sleepSession = "sleepSession"
    case mealLog = "mealLog"
    case workout = "workout"
    case workoutTemplate = "workoutTemplate"
    
    // Lume events
    case moodEntry = "moodEntry"
    case journalEntry = "journalEntry"
    case goal = "goal"
    case chatMessage = "chatMessage"
    
    public var displayName: String {
        switch self {
        case .progressEntry: return "Progress Entry"
        case .physicalAttribute: return "Physical Attribute"
        case .activitySnapshot: return "Activity Snapshot"
        case .profileMetadata: return "Profile Metadata"
        case .profilePhysical: return "Physical Profile"
        case .sleepSession: return "Sleep Session"
        case .mealLog: return "Meal Log"
        case .workout: return "Workout"
        case .workoutTemplate: return "Workout Template"
        case .moodEntry: return "Mood Entry"
        case .journalEntry: return "Journal Entry"
        case .goal: return "Goal"
        case .chatMessage: return "Chat Message"
        }
    }
}

/// Processing status for outbox events
public enum OutboxEventStatus: String, Codable, CaseIterable, Sendable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    
    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
    
    public var emoji: String {
        switch self {
        case .pending: return "⏳"
        case .processing: return "🔄"
        case .completed: return "✅"
        case .failed: return "❌"
        }
    }
}

/// Type-safe metadata for outbox events
public enum OutboxMetadata: Codable, Sendable {
    case progressEntry(metricType: String, value: Double, unit: String)
    case moodEntry(valence: Double, labels: [String])
    case journalEntry(wordCount: Int, linkedMoodID: UUID?)
    case sleepSession(duration: TimeInterval, quality: Double?)
    case mealLog(calories: Double, macros: [String: Double])
    case workout(type: String, duration: TimeInterval)
    case goal(title: String, category: String)
    case generic([String: String])
}

// MARK: - OutboxEvent Extensions

public extension OutboxEvent {
    /// Check if event is eligible for retry
    var canRetry: Bool {
        status == .failed && attemptCount < maxAttempts
    }
    
    /// Check if event is stale (old pending events that might need attention)
    var isStale: Bool {
        guard status == .pending else { return false }
        let staleThreshold: TimeInterval = 300  // 5 minutes
        return Date().timeIntervalSince(createdAt) > staleThreshold
    }
    
    /// Check if event should be processed
    var shouldProcess: Bool {
        status == .pending || canRetry
    }
    
    /// Calculate next retry delay using exponential backoff
    func nextRetryDelay(retryDelays: [TimeInterval] = [1, 5, 30, 120, 600]) -> TimeInterval? {
        guard canRetry else { return nil }
        let index = min(attemptCount, retryDelays.count - 1)
        return retryDelays[index]
    }
}
```

**File:** `FitIQCore/Sources/FitIQCore/Sync/Domain/OutboxStatistics.swift`

```swift
import Foundation

/// Statistics about outbox events
public struct OutboxStatistics: Codable, Sendable {
    public let totalEvents: Int
    public let pendingCount: Int
    public let processingCount: Int
    public let completedCount: Int
    public let failedCount: Int
    public let staleCount: Int
    public let oldestPendingDate: Date?
    public let newestCompletedDate: Date?
    
    public init(
        totalEvents: Int,
        pendingCount: Int,
        processingCount: Int,
        completedCount: Int,
        failedCount: Int,
        staleCount: Int,
        oldestPendingDate: Date? = nil,
        newestCompletedDate: Date? = nil
    ) {
        self.totalEvents = totalEvents
        self.pendingCount = pendingCount
        self.processingCount = processingCount
        self.completedCount = completedCount
        self.failedCount = failedCount
        self.staleCount = staleCount
        self.oldestPendingDate = oldestPendingDate
        self.newestCompletedDate = newestCompletedDate
    }
    
    public var successRate: Double {
        let total = pendingCount + processingCount + completedCount + failedCount
        guard total > 0 else { return 100.0 }
        return (Double(completedCount) / Double(total)) * 100.0
    }
    
    public var hasIssues: Bool {
        failedCount > 0 || staleCount > 0 || pendingCount > 20
    }
    
    public var statusSummary: String {
        """
        Total: \(totalEvents) | Pending: \(pendingCount) | Processing: \(processingCount) | \
        Completed: \(completedCount) | Failed: \(failedCount) | Stale: \(staleCount)
        """
    }
}
```

---

### Step 1.2: Create Repository Protocol

**File:** `FitIQCore/Sources/FitIQCore/Sync/Ports/OutboxRepositoryProtocol.swift`

```swift
import Foundation

/// Protocol defining the contract for outbox event persistence and retrieval
/// Implements the Outbox Pattern for reliable data synchronization
public protocol OutboxRepositoryProtocol: Sendable {
    
    // MARK: - Event Creation
    
    /// Creates a new outbox event for later processing
    /// - Parameters:
    ///   - eventType: Type of event to create
    ///   - entityID: ID of the entity that needs syncing
    ///   - userID: User this event belongs to
    ///   - isNewRecord: Whether this is a new record or an update
    ///   - metadata: Additional metadata for the event
    ///   - priority: Priority (higher = process first)
    /// - Returns: The created outbox event
    func createEvent(
        eventType: OutboxEventType,
        entityID: UUID,
        userID: String,
        isNewRecord: Bool,
        metadata: OutboxMetadata?,
        priority: Int
    ) async throws -> OutboxEvent
    
    // MARK: - Event Retrieval
    
    /// Fetches events that need processing (pending or eligible for retry)
    /// - Parameters:
    ///   - userID: Filter by user ID (nil for all users)
    ///   - limit: Maximum number of events to return
    /// - Returns: Array of events ready for processing, ordered by priority and creation time
    func fetchPendingEvents(
        forUserID userID: String?,
        limit: Int?
    ) async throws -> [OutboxEvent]
    
    /// Fetches events by status
    /// - Parameters:
    ///   - status: Status to filter by
    ///   - userID: Filter by user ID (nil for all users)
    ///   - limit: Maximum number of events to return
    /// - Returns: Array of events with the specified status
    func fetchEvents(
        withStatus status: OutboxEventStatus,
        forUserID userID: String?,
        limit: Int?
    ) async throws -> [OutboxEvent]
    
    /// Fetches a specific event by ID
    /// - Parameter id: Event ID
    /// - Returns: The event if found, nil otherwise
    func fetchEvent(byID id: UUID) async throws -> OutboxEvent?
    
    /// Fetches events for a specific entity
    /// - Parameters:
    ///   - entityID: Entity ID to search for
    ///   - eventType: Filter by event type (nil for all types)
    /// - Returns: Array of events for the entity
    func fetchEvents(
        forEntityID entityID: UUID,
        eventType: OutboxEventType?
    ) async throws -> [OutboxEvent]
    
    // MARK: - Event Updates
    
    /// Updates an existing event
    /// - Parameter event: Event to update
    func updateEvent(_ event: OutboxEvent) async throws
    
    /// Marks an event as processing
    /// - Parameter eventID: ID of event to mark
    func markAsProcessing(_ eventID: UUID) async throws
    
    /// Marks an event as completed
    /// - Parameter eventID: ID of event to mark
    func markAsCompleted(_ eventID: UUID) async throws
    
    /// Marks an event as failed with error message
    /// - Parameters:
    ///   - eventID: ID of event to mark
    ///   - error: Error message
    func markAsFailed(_ eventID: UUID, error: String) async throws
    
    /// Resets failed events for retry
    /// - Parameter eventIDs: IDs of events to reset
    func resetForRetry(_ eventIDs: [UUID]) async throws
    
    // MARK: - Event Deletion
    
    /// Deletes completed events older than specified date
    /// - Parameter olderThan: Delete events completed before this date
    /// - Returns: Number of events deleted
    @discardableResult
    func deleteCompletedEvents(olderThan date: Date) async throws -> Int
    
    /// Deletes a specific event
    /// - Parameter eventID: ID of event to delete
    func deleteEvent(_ eventID: UUID) async throws
    
    /// Deletes outbox events for specific entity IDs
    /// - Parameter entityIDs: Array of entity IDs whose events should be deleted
    /// - Returns: Number of events deleted
    @discardableResult
    func deleteEvents(forEntityIDs entityIDs: [UUID]) async throws -> Int
    
    /// Deletes all outbox events for a specific user (emergency cleanup)
    /// - Parameter userID: User ID whose events should be deleted
    /// - Returns: Number of events deleted
    @discardableResult
    func deleteAllEvents(forUserID userID: String) async throws -> Int
    
    // MARK: - Statistics
    
    /// Gets statistics about outbox events
    /// - Parameter userID: Filter by user ID (nil for all users)
    /// - Returns: Summary of event counts by status
    func getStatistics(forUserID userID: String?) async throws -> OutboxStatistics
    
    /// Checks if there are any stale events (pending for too long)
    /// - Parameter userID: Filter by user ID (nil for all users)
    /// - Returns: Array of stale events
    func getStaleEvents(forUserID userID: String?) async throws -> [OutboxEvent]
}
```

---

### Step 1.3: Create Processor Service

**File:** `FitIQCore/Sources/FitIQCore/Sync/Services/OutboxProcessorService.swift`

```swift
import Foundation

/// Service that processes outbox events to sync data with remote API
/// Implements the Outbox Pattern with robust retry logic and error handling
public actor OutboxProcessorService {
    
    // MARK: - Configuration
    
    public struct Configuration: Sendable {
        public let batchSize: Int
        public let processingInterval: TimeInterval
        public let maxConcurrentOperations: Int
        public let retryDelays: [TimeInterval]
        public let cleanupInterval: TimeInterval
        
        public init(
            batchSize: Int = 10,
            processingInterval: TimeInterval = 0.1,
            maxConcurrentOperations: Int = 3,
            retryDelays: [TimeInterval] = [1, 5, 30, 120, 600],
            cleanupInterval: TimeInterval = 300
        ) {
            self.batchSize = batchSize
            self.processingInterval = processingInterval
            self.maxConcurrentOperations = maxConcurrentOperations
            self.retryDelays = retryDelays
            self.cleanupInterval = cleanupInterval
        }
        
        public static let `default` = Configuration()
    }
    
    // MARK: - Event Handler Protocol
    
    public protocol OutboxEventHandler: Sendable {
        func canHandle(eventType: OutboxEventType) -> Bool
        func handle(event: OutboxEvent) async throws
    }
    
    // MARK: - Properties
    
    private let repository: OutboxRepositoryProtocol
    private let configuration: Configuration
    private var handlers: [any OutboxEventHandler] = []
    
    private var isProcessing = false
    private var processingTask: Task<Void, Never>?
    private var cleanupTask: Task<Void, Never>?
    private var currentUserID: String?
    
    // MARK: - Initialization
    
    public init(
        repository: OutboxRepositoryProtocol,
        configuration: Configuration = .default
    ) {
        self.repository = repository
        self.configuration = configuration
    }
    
    // MARK: - Handler Registration
    
    public func registerHandler(_ handler: any OutboxEventHandler) {
        handlers.append(handler)
    }
    
    // MARK: - Processing Control
    
    /// Starts processing outbox events for a specific user
    /// - Parameter userID: User ID to process events for
    public func startProcessing(forUserID userID: String) {
        // If already processing for a different user, stop first
        if isProcessing {
            print("⚠️ [OutboxProcessor] Already processing, restarting for user \(userID)")
            stopProcessing()
        }
        
        currentUserID = userID
        isProcessing = true
        
        print("🚀 [OutboxProcessor] Starting for user \(userID)")
        
        // Start periodic processing
        processingTask = Task { [weak self] in
            await self?.processLoop()
        }
        
        // Start periodic cleanup
        cleanupTask = Task { [weak self] in
            await self?.cleanupLoop()
        }
    }
    
    /// Stops processing outbox events
    public func stopProcessing() {
        guard isProcessing else { return }
        
        print("🛑 [OutboxProcessor] Stopping")
        
        isProcessing = false
        currentUserID = nil
        
        processingTask?.cancel()
        processingTask = nil
        
        cleanupTask?.cancel()
        cleanupTask = nil
    }
    
    /// Triggers immediate processing (skips waiting for next poll cycle)
    public func triggerImmediateProcessing() {
        guard isProcessing else {
            print("⚠️ [OutboxProcessor] Cannot trigger - processor not started")
            return
        }
        
        print("⚡ [OutboxProcessor] Triggering immediate processing")
        
        Task {
            await self.processBatch()
        }
    }
    
    // MARK: - Private Processing Logic
    
    private func processLoop() async {
        while isProcessing && !Task.isCancelled {
            await processBatch()
            
            // Wait for next cycle
            try? await Task.sleep(nanoseconds: UInt64(configuration.processingInterval * 1_000_000_000))
        }
    }
    
    private func processBatch() async {
        guard let userID = currentUserID else { return }
        
        do {
            // Fetch pending events
            let events = try await repository.fetchPendingEvents(
                forUserID: userID,
                limit: configuration.batchSize
            )
            
            guard !events.isEmpty else { return }
            
            print("📦 [OutboxProcessor] Processing \(events.count) events")
            
            // Process events concurrently (up to max concurrent operations)
            await withTaskGroup(of: Void.self) { group in
                for event in events.prefix(configuration.maxConcurrentOperations) {
                    group.addTask { [weak self] in
                        await self?.processEvent(event)
                    }
                }
            }
            
        } catch {
            print("❌ [OutboxProcessor] Error fetching events: \(error)")
        }
    }
    
    private func processEvent(_ event: OutboxEvent) async {
        do {
            // Mark as processing
            try await repository.markAsProcessing(event.id)
            
            // Find handler
            guard let handler = handlers.first(where: { $0.canHandle(eventType: event.eventType) }) else {
                throw OutboxProcessorError.noHandlerFound(eventType: event.eventType)
            }
            
            // Handle event
            try await handler.handle(event: event)
            
            // Mark as completed
            try await repository.markAsCompleted(event.id)
            
            print("✅ [OutboxProcessor] Completed: \(event.eventType.displayName) (\(event.id))")
            
        } catch {
            // Mark as failed with error message
            try? await repository.markAsFailed(event.id, error: error.localizedDescription)
            
            print("❌ [OutboxProcessor] Failed: \(event.eventType.displayName) (\(event.id)) - \(error)")
        }
    }
    
    private func cleanupLoop() async {
        while isProcessing && !Task.isCancelled {
            // Wait for cleanup interval
            try? await Task.sleep(nanoseconds: UInt64(configuration.cleanupInterval * 1_000_000_000))
            
            guard isProcessing else { break }
            
            do {
                // Delete completed events older than 24 hours
                let cutoffDate = Date().addingTimeInterval(-86400)
                let deletedCount = try await repository.deleteCompletedEvents(olderThan: cutoffDate)
                
                if deletedCount > 0 {
                    print("🧹 [OutboxProcessor] Cleaned up \(deletedCount) old completed events")
                }
            } catch {
                print("⚠️ [OutboxProcessor] Cleanup error: \(error)")
            }
        }
    }
    
    // MARK: - Statistics
    
    public func getStatistics() async throws -> OutboxStatistics {
        guard let userID = currentUserID else {
            throw OutboxProcessorError.notStarted
        }
        
        return try await repository.getStatistics(forUserID: userID)
    }
}

// MARK: - Errors

public enum OutboxProcessorError: LocalizedError {
    case notStarted
    case noHandlerFound(eventType: OutboxEventType)
    
    public var errorDescription: String? {
        switch self {
        case .notStarted:
            return "Outbox processor not started"
        case .noHandlerFound(let eventType):
            return "No handler found for event type: \(eventType.rawValue)"
        }
    }
}
```

---

### Step 1.4: Update Package Manifest

**File:** `FitIQCore/Package.swift`

Add new target:

```swift
.target(
    name: "FitIQCore",
    dependencies: [],
    path: "Sources/FitIQCore"
),
```

Ensure the new Sync module is included in the existing target structure.

---

## Phase 2: Migrate FitIQ (3-4 hours)

### Step 2.1: Update Dependencies

**File:** `FitIQ/FitIQ.xcodeproj/project.pbxproj`

Add FitIQCore dependency if not already present (should already be added from Auth migration).

---

### Step 2.2: Remove Duplicated Files

Delete these files (now in FitIQCore):
- ❌ `FitIQ/Domain/Entities/Outbox/OutboxEventTypes.swift` → Use `FitIQCore.OutboxEventType`
- ⚠️ Keep `FitIQ/Domain/Ports/OutboxRepositoryProtocol.swift` temporarily (update to extend FitIQCore protocol)

---

### Step 2.3: Update SwiftData Schema

**File:** `FitIQ/Infrastructure/Persistence/Schema/SchemaV3.swift`

No changes needed - SDOutboxEvent already matches FitIQCore model.

---

### Step 2.4: Update Repository Implementation

**File:** `FitIQ/Infrastructure/Persistence/SwiftDataOutboxRepository.swift`

```swift
import Foundation
import SwiftData
import FitIQCore

/// SwiftData implementation of FitIQCore OutboxRepositoryProtocol
final class SwiftDataOutboxRepository: OutboxRepositoryProtocol {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Event Creation
    
    func createEvent(
        eventType: FitIQCore.OutboxEventType,
        entityID: UUID,
        userID: String,
        isNewRecord: Bool,
        metadata: FitIQCore.OutboxMetadata?,
        priority: Int
    ) async throws -> FitIQCore.OutboxEvent {
        // Convert metadata to JSON string
        let metadataString: String?
        if let metadata = metadata {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(metadata),
               let string = String(data: data, encoding: .utf8) {
                metadataString = string
            } else {
                metadataString = nil
            }
        } else {
            metadataString = nil
        }
        
        // Create SwiftData entity
        let sdEvent = SDOutboxEvent(
            eventType: eventType.rawValue,
            entityID: entityID,
            userID: userID,
            status: FitIQCore.OutboxEventStatus.pending.rawValue,
            metadata: metadataString,
            priority: priority,
            isNewRecord: isNewRecord
        )
        
        modelContext.insert(sdEvent)
        try modelContext.save()
        
        return sdEvent.toDomain()
    }
    
    // ... implement remaining protocol methods (convert between SDOutboxEvent and OutboxEvent)
}

// MARK: - Conversion Extensions

extension SDOutboxEvent {
    func toDomain() -> FitIQCore.OutboxEvent {
        // Parse metadata
        let parsedMetadata: FitIQCore.OutboxMetadata?
        if let metadataString = metadata,
           let data = metadataString.data(using: .utf8) {
            let decoder = JSONDecoder()
            parsedMetadata = try? decoder.decode(FitIQCore.OutboxMetadata.self, from: data)
        } else {
            parsedMetadata = nil
        }
        
        return FitIQCore.OutboxEvent(
            id: id,
            eventType: FitIQCore.OutboxEventType(rawValue: eventType) ?? .progressEntry,
            entityID: entityID,
            userID: userID,
            status: FitIQCore.OutboxEventStatus(rawValue: status) ?? .pending,
            createdAt: createdAt,
            lastAttemptAt: lastAttemptAt,
            attemptCount: attemptCount,
            maxAttempts: maxAttempts,
            errorMessage: errorMessage,
            completedAt: completedAt,
            metadata: parsedMetadata,
            priority: priority,
            isNewRecord: isNewRecord
        )
    }
}
```

---

### Step 2.5: Create Event Handlers

**File:** `FitIQ/Infrastructure/Sync/FitIQOutboxEventHandlers.swift`

```swift
import Foundation
import FitIQCore

/// Handler for progress entry events
struct ProgressEntryOutboxHandler: OutboxProcessorService.OutboxEventHandler {
    private let progressRepository: ProgressRepositoryProtocol
    private let remoteDataSync: RemoteHealthDataSyncPort
    
    init(
        progressRepository: ProgressRepositoryProtocol,
        remoteDataSync: RemoteHealthDataSyncPort
    ) {
        self.progressRepository = progressRepository
        self.remoteDataSync = remoteDataSync
    }
    
    func canHandle(eventType: OutboxEventType) -> Bool {
        eventType == .progressEntry
    }
    
    func handle(event: OutboxEvent) async throws {
        // Fetch the progress entry
        guard let entry = try await progressRepository.fetchByID(event.entityID) else {
            throw OutboxHandlerError.entityNotFound(id: event.entityID)
        }
        
        // Sync to backend
        try await remoteDataSync.syncProgressEntry(entry)
    }
}

// Create similar handlers for other event types:
// - SleepSessionOutboxHandler
// - MealLogOutboxHandler
// - WorkoutOutboxHandler
// - etc.

enum OutboxHandlerError: LocalizedError {
    case entityNotFound(id: UUID)
    
    var errorDescription: String? {
        switch self {
        case .entityNotFound(let id):
            return "Entity not found: \(id)"
        }
    }
}
```

---

### Step 2.6: Update Processor Service

**File:** `FitIQ/Infrastructure/Network/OutboxProcessorService.swift`

Replace entire file with wrapper around FitIQCore service:

```swift
import Foundation
import FitIQCore

/// FitIQ-specific wrapper around FitIQCore OutboxProcessorService
public final class FitIQOutboxProcessor {
    
    private let coreProcessor: FitIQCore.OutboxProcessorService
    
    public init(
        repository: OutboxRepositoryProtocol,
        progressRepository: ProgressRepositoryProtocol,
        remoteDataSync: RemoteHealthDataSyncPort,
        sleepRepository: SleepRepositoryProtocol,
        sleepAPIClient: SleepAPIClientProtocol,
        mealLogRepository: MealLogLocalStorageProtocol,
        nutritionAPIClient: MealLogRemoteAPIProtocol,
        workoutRepository: WorkoutRepositoryProtocol,
        workoutAPIClient: WorkoutAPIClientProtocol,
        configuration: FitIQCore.OutboxProcessorService.Configuration = .default
    ) {
        self.coreProcessor = FitIQCore.OutboxProcessorService(
            repository: repository,
            configuration: configuration
        )
        
        // Register handlers
        Task {
            await coreProcessor.registerHandler(
                ProgressEntryOutboxHandler(
                    progressRepository: progressRepository,
                    remoteDataSync: remoteDataSync
                )
            )
            
            // Register other handlers...
        }
    }
    
    public func startProcessing(forUserID userID: UUID) {
        Task {
            await coreProcessor.startProcessing(forUserID: userID.uuidString)
        }
    }
    
    public func stopProcessing() {
        Task {
            await coreProcessor.stopProcessing()
        }
    }
    
    public func triggerImmediateProcessing() {
        Task {
            await coreProcessor.triggerImmediateProcessing()
        }
    }
}
```

---

### Step 2.7: Update AppDependencies

**File:** `FitIQ/DI/AppDependencies.swift`

Update to use new processor:

```swift
lazy var outboxProcessor: FitIQOutboxProcessor = FitIQOutboxProcessor(
    repository: outboxRepository,
    progressRepository: progressRepository,
    remoteDataSync: remoteDataSync,
    sleepRepository: sleepRepository,
    sleepAPIClient: sleepAPIClient,
    mealLogRepository: mealLogRepository,
    nutritionAPIClient: nutritionAPIClient,
    workoutRepository: workoutRepository,
    workoutAPIClient: workoutAPIClient
)
```

---

## Phase 3: Migrate Lume (5-7 hours)

### Step 3.1: Create New Schema Version

**File:** `lume/Data/Persistence/SchemaVersioning.swift`

Add SchemaV7:

```swift
/// Version 7: Enhanced Outbox Pattern (aligned with FitIQCore)
/// - Adds: entityID, userID, priority, metadata, isNewRecord to SDOutboxEvent
/// - Renames: retryCount → attemptCount
/// - Changes: payload (Data) → metadata (String, JSON)
enum SchemaV7: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 7)
    
    static var models: [any PersistentModel.Type] {
        [SDOutboxEvent.self, SDMoodEntry.self, SDJournalEntry.self, SDGoal.self, SDChatConversation.self, SDChatMessage.self]
    }
    
    @Model
    final class SDOutboxEvent {
        // Existing fields
        var id: UUID
        var createdAt: Date
        var eventType: String
        var status: String
        var lastAttemptAt: Date?
        var completedAt: Date?
        var errorMessage: String?
        
        // Enhanced fields (new in V7)
        var entityID: UUID        // Default: id (self-referencing)
        var userID: String        // Must be populated post-migration
        var attemptCount: Int     // Migrated from retryCount
        var maxAttempts: Int      // Default: 5
        var metadata: String?     // Replaces payload (migrate to JSON)
        var priority: Int         // Default: 0
        var isNewRecord: Bool     // Default: true
        
        init(
            id: UUID = UUID(),
            createdAt: Date = Date(),
            eventType: String,
            status: String = "pending",
            lastAttemptAt: Date? = nil,
            completedAt: Date? = nil,
            errorMessage: String? = nil,
            entityID: UUID,
            userID: String,
            attemptCount: Int = 0,
            maxAttempts: Int = 5,
            metadata: String? = nil,
            priority: Int = 0,
            isNewRecord: Bool = true
        ) {
            self.id = id
            self.createdAt = createdAt
            self.eventType = eventType
            self.status = status
            self.lastAttemptAt = lastAttemptAt
            self.completedAt = completedAt
            self.errorMessage = errorMessage
            self.entityID = entityID
            self.userID = userID
            self.attemptCount = attemptCount
            self.maxAttempts = maxAttempts
            self.metadata = metadata
            self.priority = priority
            self.isNewRecord = isNewRecord
        }
    }
    
    // Reuse other models from SchemaV6
    typealias SDMoodEntry = SchemaV6.SDMoodEntry
    typealias SDJournalEntry = SchemaV6.SDJournalEntry
    typealias SDGoal = SchemaV6.SDGoal
    typealias SDChatConversation = SchemaV6.SDChatConversation
    typealias SDChatMessage = SchemaV6.SDChatMessage
}
```

---

### Step 3.2: Create Migration Logic

**File:** `lume/Data/Persistence/OutboxMigrationV6ToV7.swift`

```swift
import Foundation
import SwiftData
import FitIQCore

/// Custom migration from SchemaV6 to SchemaV7 for Outbox Pattern enhancement
final class OutboxMigrationV6ToV7 {
    
    /// Migrate outbox events from V6 to V7
    /// - Parameter modelContext: Model context for migration
    static func migrate(modelContext: ModelContext, currentUserID: String) async throws {
        print("🔄 [Migration] Starting Outbox V6→V7 migration...")
        
        // Fetch all V6 outbox events
        let v6Descriptor = FetchDescriptor<SchemaV6.SDOutboxEvent>()
        let v6Events = try modelContext.fetch(v6Descriptor)
        
        print("📦 [Migration] Found \(v6Events.count) V6 outbox events")
        
        guard !v6Events.isEmpty else {
            print("✅ [Migration] No events to migrate")
            return
        }
        
        var migratedCount = 0
        var errorCount = 0
        
        for v6Event in v6Events {
            do {
                // Convert payload (Data) to metadata (JSON string)
                let metadataString: String?
                if !v6Event.payload.isEmpty {
                    // Attempt to convert payload to JSON string
                    if let jsonObject = try? JSONSerialization.jsonObject(with: v6Event.payload),
                       let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        metadataString = jsonString
                    } else {
                        // If payload is not JSON, base64 encode it
                        metadataString = v6Event.payload.base64EncodedString()
                    }
                } else {
                    metadataString = nil
                }
                
                // Create V7 event
                let v7Event = SchemaV7.SDOutboxEvent(
                    id: v6Event.id,
                    createdAt: v6Event.createdAt,
                    eventType: v6Event.eventType,
                    status: v6Event.status,
                    lastAttemptAt: v6Event.lastAttemptAt,
                    completedAt: v6Event.completedAt,
                    errorMessage: v6Event.errorMessage,
                    entityID: v6Event.id,  // Use event ID as entity ID (self-referencing)
                    userID: currentUserID,  // Use current user ID
                    attemptCount: v6Event.retryCount,  // Migrate retry count
                    maxAttempts: 5,
                    metadata: metadataString,
                    priority: 0,
                    isNewRecord: true
                )
                
                // Delete old V6 event
                modelContext.delete(v6Event)
                
                // Insert new V7 event
                modelContext.insert(v7Event)
                
                migratedCount += 1
                
            } catch {
                print("⚠️ [Migration] Failed to migrate event \(v6Event.id): \(error)")
                errorCount += 1
            }
        }
        
        // Save changes
        try modelContext.save()
        
        print("✅ [Migration] Migrated \(migratedCount) events (\(errorCount) errors)")
    }
}
```

---

### Step 3.3: Update Schema Version

**File:** `lume/Data/Persistence/SchemaVersioning.swift`

```swift
enum SchemaVersioning {
    /// Current schema version
    static let current = SchemaV7.self  // Changed from SchemaV6
}
```

---

### Step 3.4: Update Repository

**File:** `lume/Data/Repositories/SwiftDataOutboxRepository.swift`

Replace with FitIQCore-compliant implementation (similar to FitIQ Step 2.4).

---

### Step 3.5: Create Event Handlers

**File:** `lume/Services/Outbox/LumeOutboxEventHandlers.swift`

```swift
import Foundation
import FitIQCore

/// Handler for mood entry events
struct MoodEntryOutboxHandler: OutboxProcessorService.OutboxEventHandler {
    private let moodBackendService: MoodBackendServiceProtocol
    private let tokenStorage: TokenStorageProtocol
    private let modelContext: ModelContext
    
    func canHandle(eventType: OutboxEventType) -> Bool {
        eventType == .moodEntry
    }
    
    func handle(event: OutboxEvent) async throws {
        // Get access token
        guard let token = try await tokenStorage.getToken() else {
            throw OutboxHandlerError.authenticationRequired
        }
        
        // Parse payload
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        guard let metadataString = event.metadata?.jsonString,
              let payloadData = metadataString.data(using: .utf8) else {
            throw OutboxHandlerError.invalidPayload
        }
        
        // Handle based on event type
        if event.eventType.contains("created") {
            let payload = try decoder.decode(MoodCreatedPayload.self, from: payloadData)
            try await moodBackendService.createMood(payload, accessToken: token.accessToken)
        } else if event.eventType.contains("updated") {
            let payload = try decoder.decode(MoodUpdatedPayload.self, from: payloadData)
            try await moodBackendService.updateMood(payload, accessToken: token.accessToken)
        }
    }
}

// Create similar handlers for:
// - JournalEntryOutboxHandler
// - GoalOutboxHandler
// - ChatMessageOutboxHandler

enum OutboxHandlerError: LocalizedError {
    case authenticationRequired
    case invalidPayload
    
    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "Authentication required"
        case .invalidPayload:
            return "Invalid event payload"
        }
    }
}

extension OutboxMetadata {
    var jsonString: String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
}
```

---

### Step 3.6: Replace Processor Service

**File:** `lume/Services/Outbox/OutboxProcessorService.swift`

Replace entire file (similar to FitIQ Step 2.6).

---

### Step 3.7: Update All createEvent Calls

Search for all `outboxRepository.createEvent` calls and update:

**Before:**
```swift
try await outboxRepository.createEvent(
    type: "mood.created",
    payload: payloadData
)
```

**After:**
```swift
try await outboxRepository.createEvent(
    eventType: .moodEntry,
    entityID: moodEntry.id,
    userID: currentUserID,
    isNewRecord: true,
    metadata: .moodEntry(valence: moodEntry.valence, labels: moodEntry.labels),
    priority: 5
)
```

---

### Step 3.8: Run Migration on App Launch

**File:** `lume/lumeApp.swift`

```swift
import SwiftUI
import SwiftData

@main
struct lumeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await performMigrationIfNeeded()
                }
        }
        .modelContainer(for: SchemaVersioning.current)
    }
    
    private func performMigrationIfNeeded() async {
        // Check if migration needed
        let migrationKey = "outbox_migration_v6_to_v7_completed"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            return
        }
        
        // Get current user ID
        guard let currentUserID = UserSession.shared.currentUserId?.uuidString else {
            print("⚠️ [Migration] No user logged in, skipping migration")
            return
        }
        
        // Perform migration
        do {
            let modelContext = // ... get model context
            try await OutboxMigrationV6ToV7.migrate(
                modelContext: modelContext,
                currentUserID: currentUserID
            )
            
            UserDefaults.standard.set(true, forKey: migrationKey)
            print("✅ [Migration] Outbox V6→V7 migration complete")
            
        } catch {
            print("❌ [Migration] Failed: \(error)")
        }
    }
}
```

---

## Phase 4: Testing & Verification (2-3 hours)

### Step 4.1: Unit Tests

Create tests for FitIQCore:
- `OutboxEventTests.swift` - Test domain model
- `OutboxRepositoryTests.swift` - Test repository with mock
- `OutboxProcessorServiceTests.swift` - Test processor logic

### Step 4.2: Integration Tests

**FitIQ:**
- Create test progress entry → Verify outbox event created
- Process outbox → Verify backend sync
- Test retry logic → Verify exponential backoff
- Test priority → Verify high-priority events processed first

**Lume:**
- Verify migration from V6 to V7
- Create test mood entry → Verify outbox event created
- Process outbox → Verify backend sync
- Test all event types (mood, journal, goal, chat)

### Step 4.3: Manual Testing

1. Fresh install (no migration)
2. Existing user (migration required)
3. Offline sync (events queued)
4. Online sync (events processed)
5. Error scenarios (retry logic)
6. Statistics reporting

---

## Rollback Plan

If issues arise, rollback is straightforward:

### FitIQ Rollback
1. Revert to commit before migration
2. No schema changes needed

### Lume Rollback
1. Revert to commit before migration
2. Change `SchemaVersioning.current = SchemaV6.self`
3. Delete V7 schema file
4. Rebuild app

**Data Safety:** All data remains in V6 format until migration runs successfully.

---

## Success Criteria

- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] FitIQ builds without errors
- [ ] Lume builds without errors
- [ ] Migration completes without data loss
- [ ] Outbox statistics show 100% event processing
- [ ] No stale events detected after 10 minutes
- [ ] Success rate > 99%
- [ ] Processing latency < 1s for high-priority events
- [ ] Code duplication reduced by 500+ lines

---

## Timeline

| Phase | Estimated Time | Deliverable |
|-------|----------------|-------------|
| Phase 1: FitIQCore Foundation | 4-5 hours | Domain models, protocols, processor service in FitIQCore |
| Phase 2: FitIQ Migration | 3-4 hours | FitIQ using FitIQCore Outbox |
| Phase 3: Lume Migration | 5-7 hours | Lume using FitIQCore Outbox with schema migration |
| Phase 4: Testing | 2-3 hours | Unit tests, integration tests, manual verification |
| **Total** | **14-19 hours** | Unified Outbox Pattern across all projects |

---

## Next Steps

1. ✅ Review this plan with team
2. ⏳ Create FitIQCore foundation (Phase 1)
3. ⏳ Migrate FitIQ (Phase 2)
4. ⏳ Migrate Lume (Phase 3)
5. ⏳ Test and verify (Phase 4)
6. ⏳ Document usage guide
7. ✅ Celebrate 500+ lines of code eliminated! 🎉

---

**Status:** Ready for implementation  
**Risk Level:** Medium (schema migration for Lume)  
**Impact:** High (significant reliability and maintainability improvements)