//
//  SchemaCompatibilityLayer.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: Handle schema version mismatches gracefully to prevent crashes
//

import Foundation
import SwiftData

/// Compatibility layer to handle legacy schema entities
/// Updated for SchemaV9 which uses relationships instead of userID strings
final class SchemaCompatibilityLayer {

    // MARK: - Error Types

    enum SchemaCompatibilityError: Error, LocalizedError {
        case invalidUserID
        case incompatibleSchema(Error)

        var errorDescription: String? {
            switch self {
            case .invalidUserID:
                return "Invalid user ID format for schema compatibility layer"
            case .incompatibleSchema(let error):
                return "Incompatible schema: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Safe Fetch with Schema Fallback

    /// Safely fetches progress entries, handling schema version mismatches
    /// Falls back to manual entity conversion if schema mismatch occurs
    static func safeFetchProgressEntries(
        from context: ModelContext,
        userID: String,
        type: String?,
        syncStatus: String?,
        limit: Int? = nil
    ) throws -> [SDProgressEntry] {

        // Attempt normal fetch with current schema
        do {
            // Convert String userID to UUID for predicate comparison
            guard let userUUID = UUID(uuidString: userID) else {
                throw SchemaCompatibilityError.invalidUserID
            }

            let typeRawValue = type
            let syncStatusRawValue = syncStatus

            // V9: Use relationship to userProfile instead of userID string
            let predicate = #Predicate<SDProgressEntry> { entry in
                entry.userProfile?.id == userUUID
                    && (typeRawValue == nil || entry.type == typeRawValue!)
                    && (syncStatusRawValue == nil || entry.syncStatus == syncStatusRawValue!)
            }

            var descriptor = FetchDescriptor<SDProgressEntry>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            descriptor.predicate = predicate
            if let limit = limit {
                descriptor.fetchLimit = limit
            }

            let results = try context.fetch(descriptor)

            print(
                "SchemaCompatibilityLayer: ✅ Fetched \(results.count) entries with current schema")
            return results

        } catch {
            print("SchemaCompatibilityLayer: ⚠️ Schema mismatch detected: \(error)")
            print("SchemaCompatibilityLayer: 🔄 Attempting fallback fetch...")

            // Fallback: Fetch without predicate, filter manually
            return try fallbackFetchProgressEntries(
                from: context,
                userID: userID,
                type: type,
                syncStatus: syncStatus,
                limit: limit
            )
        }
    }

    /// Fallback fetch method that handles schema version mismatches
    /// Fetches all entities and filters manually to avoid predicate issues
    private static func fallbackFetchProgressEntries(
        from context: ModelContext,
        userID: String,
        type: String?,
        syncStatus: String?,
        limit: Int?
    ) throws -> [SDProgressEntry] {

        do {
            // Fetch recent progress entries with limit to avoid full table scan
            var descriptor = FetchDescriptor<SDProgressEntry>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            if let limit = limit {
                descriptor.fetchLimit = limit
            }

            let allEntries = try context.fetch(descriptor)

            print("SchemaCompatibilityLayer: Fetched \(allEntries.count) total entries")

            // Manual filtering
            let filtered = allEntries.filter { entry in
                // Filter by userID (V9: use relationship)
                guard entry.userProfile?.id.uuidString == userID else { return false }

                // Filter by type if specified
                if let type = type, entry.type != type {
                    return false
                }

                // Filter by syncStatus if specified
                if let syncStatus = syncStatus, entry.syncStatus != syncStatus {
                    return false
                }

                return true
            }

            print("SchemaCompatibilityLayer: ✅ Filtered to \(filtered.count) matching entries")
            return filtered

        } catch {
            print("SchemaCompatibilityLayer: ❌ Fallback fetch also failed: \(error)")

            // Last resort: Return empty array and log error
            print("SchemaCompatibilityLayer: 🚨 DATABASE SCHEMA INCOMPATIBILITY DETECTED!")
            print("SchemaCompatibilityLayer: 🚨 Database contains incompatible schema version")
            print("SchemaCompatibilityLayer: 🚨 ACTION REQUIRED: Delete app and reinstall")
            print("SchemaCompatibilityLayer: 🚨 Or use Settings → Delete All Data")

            throw SchemaCompatibilityError.incompatibleSchema(error)
        }
    }

    // MARK: - Safe Delete with Schema Fallback

    /// Safely deletes progress entries, handling schema version mismatches
    static func safeDeleteProgressEntries(
        from context: ModelContext,
        userID: String,
        type: String?
    ) throws {

        // IMMEDIATE FALLBACK: Don't even try the normal path with SchemaV2 data
        // Go straight to aggressive deletion
        print("SchemaCompatibilityLayer: Using aggressive deletion strategy")
        try fallbackDeleteProgressEntries(from: context, userID: userID, type: type)
    }

    /// Fallback delete method that handles schema version mismatches
    /// Uses multiple aggressive strategies to force deletion
    private static func fallbackDeleteProgressEntries(
        from context: ModelContext,
        userID: String,
        type: String?
    ) throws {

        print("SchemaCompatibilityLayer: Starting aggressive deletion...")

        // Strategy 1: Try to fetch and delete without breaking relationships
        do {
            let descriptor = FetchDescriptor<SDProgressEntry>()
            let allEntries = try context.fetch(descriptor)

            let entriesToDelete = allEntries.filter { entry in
                // V9: Use relationship to userProfile
                guard entry.userProfile?.id.uuidString == userID else { return false }
                if let type = type, entry.type != type { return false }
                return true
            }

            print("SchemaCompatibilityLayer: Found \(entriesToDelete.count) entries to delete")

            // Just delete - don't touch relationships
            for entry in entriesToDelete {
                context.delete(entry)
            }

            // Try to save
            do {
                try context.save()
                print(
                    "SchemaCompatibilityLayer: ✅ Aggressive delete succeeded (no relationship breaking)"
                )
                return
            } catch let saveError {
                print("SchemaCompatibilityLayer: ⚠️ Save failed: \(saveError)")
                print("SchemaCompatibilityLayer: 🔄 Trying next strategy...")
                context.rollback()
            }
        } catch let fetchError {
            print("SchemaCompatibilityLayer: ⚠️ Fetch failed: \(fetchError)")
        }

        // Strategy 2: Create new context and try there
        do {
            print("SchemaCompatibilityLayer: Strategy 2 - Using fresh ModelContext")
            let freshContext = ModelContext(context.container)

            let descriptor = FetchDescriptor<SDProgressEntry>()
            let allEntries = try freshContext.fetch(descriptor)

            let entriesToDelete = allEntries.filter { entry in
                // V9: Use relationship to userProfile
                guard entry.userProfile?.id.uuidString == userID else { return false }
                if let type = type, entry.type != type { return false }
                return true
            }

            print(
                "SchemaCompatibilityLayer: Found \(entriesToDelete.count) entries in fresh context")

            for entry in entriesToDelete {
                freshContext.delete(entry)
            }

            try freshContext.save()
            print("SchemaCompatibilityLayer: ✅ Fresh context delete succeeded")
            return

        } catch let contextError {
            print("SchemaCompatibilityLayer: ⚠️ Fresh context strategy failed: \(contextError)")
        }

        // Strategy 3: Last resort - catch the crash and report
        print("SchemaCompatibilityLayer: 🚨 All deletion strategies failed")
        print("SchemaCompatibilityLayer: 🚨 This database MUST be deleted manually")
        print("SchemaCompatibilityLayer: 🚨 Go to Settings → Delete All Data")

        throw SchemaCompatibilityError.incompatibleSchema(
            NSError(
                domain: "SchemaCompatibilityLayer", code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Database contains incompatible entities that cannot be safely deleted"
                ])
        )
    }

    // MARK: - Schema Version Detection

    /// Detects the schema version of entities in the database
    /// Returns true if schema migration is needed
    static func needsMigration(context: ModelContext) -> Bool {
        do {
            // Try to fetch a single progress entry
            var descriptor = FetchDescriptor<SDProgressEntry>()
            descriptor.fetchLimit = 1

            let _ = try context.fetch(descriptor)

            // If we can fetch without error, schema is compatible
            print("SchemaCompatibilityLayer: ✅ Schema is compatible (V9)")
            return false

        } catch {
            // If fetch fails, schema is incompatible
            print("SchemaCompatibilityLayer: ⚠️ Schema is incompatible, migration needed")
            print("SchemaCompatibilityLayer: Error: \(error)")
            return true
        }
    }

    /// Logs detailed schema information for debugging
    static func logSchemaInfo(context: ModelContext) {
        print("SchemaCompatibilityLayer: === SCHEMA DIAGNOSTICS ===")

        // Try to fetch entities and log their types
        do {
            var descriptor = FetchDescriptor<SDProgressEntry>()
            descriptor.fetchLimit = 1

            let entries = try context.fetch(descriptor)

            if let entry = entries.first {
                print("SchemaCompatibilityLayer: Sample entry ID: \(entry.id)")
                print("SchemaCompatibilityLayer: Sample entry type: \(entry.type)")
                print(
                    "SchemaCompatibilityLayer: Sample entry userProfile: \(entry.userProfile?.id.uuidString ?? "nil")"
                )
                print("SchemaCompatibilityLayer: ✅ Schema appears compatible")
            } else {
                print("SchemaCompatibilityLayer: No entries found (empty database)")
            }

        } catch {
            print("SchemaCompatibilityLayer: ❌ Schema incompatibility detected")
            print("SchemaCompatibilityLayer: Error: \(error)")
            print("SchemaCompatibilityLayer: Database likely contains SchemaV2 or V3 entities")
            print("SchemaCompatibilityLayer: ACTION REQUIRED: Delete app and reinstall")
        }

        print("SchemaCompatibilityLayer: === END DIAGNOSTICS ===")
    }
}

// MARK: - Errors

enum SchemaCompatibilityError: Error, LocalizedError {
    case incompatibleSchema(message: String, underlyingError: Error)
    case migrationRequired

    var errorDescription: String? {
        switch self {
        case .incompatibleSchema(let message, _):
            return message
        case .migrationRequired:
            return
                "Database migration required. Please delete the app and reinstall, or use Settings → Delete All Data."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .incompatibleSchema:
            return """
                Your database contains entities from an older schema version (V2 or V3).

                To fix this:
                1. Delete the app from your simulator/device
                2. Rebuild and run in Xcode
                3. A fresh SchemaV4 database will be created

                OR

                1. Open the app
                2. Go to Settings → Data Management
                3. Tap "Delete All Data"
                4. Restart the app
                """
        case .migrationRequired:
            return "Delete the app and reinstall to migrate to the latest schema version."
        }
    }
}
