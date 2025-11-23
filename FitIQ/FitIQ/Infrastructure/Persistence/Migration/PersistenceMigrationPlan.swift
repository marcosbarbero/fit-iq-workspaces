//
//  PersistenceMigrationPlan.swift
//
//  Created by Marcos Barbero on 28/09/2025.
//

import Foundation
import SwiftData

enum PersistenceMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            SchemaV1.self,
            SchemaV2.self,
            SchemaV3.self,
            SchemaV4.self,
            SchemaV5.self,
            SchemaV6.self,
            SchemaV7.self,
            SchemaV8.self,
            SchemaV9.self,
            SchemaV10.self,
            SchemaV11.self,
        ]
    }

    static var stages: [MigrationStage] {
        [
            // V1 to V2: Add SDProgressEntry model for progress tracking
            // Must use custom migration because CloudKit requires optional attributes or default values
            MigrationStage.custom(
                fromVersion: SchemaV1.self,
                toVersion: SchemaV2.self,
                willMigrate: nil,
                didMigrate: { context in
                    // No data transformation needed - just adding a new model
                    // SDProgressEntry table will be created empty
                    print(
                        "PersistenceMigrationPlan: Completed migration from V1 to V2 (added SDProgressEntry)"
                    )
                    try context.save()
                }
            ),
            // V2 to V3: Add SDOutboxEvent model for reliable background sync
            // Uses lightweight migration since SDOutboxEvent is standalone with no relationships
            MigrationStage.lightweight(
                fromVersion: SchemaV2.self,
                toVersion: SchemaV3.self
            ),
            // V3 to V4: Add SDSleepSession and SDSleepStage models for sleep tracking
            // Uses lightweight migration since sleep models are new with no data transformation needed
            MigrationStage.lightweight(
                fromVersion: SchemaV3.self,
                toVersion: SchemaV4.self
            ),
            .lightweight(
                fromVersion: SchemaV4.self,
                toVersion: SchemaV5.self),
            // V5 to V6: Add SDMealLog and SDMealLogItem models for nutrition logging
            // Uses custom migration because:
            // 1. Adding new relationship (mealLogs) to existing SDUserProfile model
            // 2. CloudKit requires optional attributes or default values for new relationships
            // 3. Need to ensure proper relationship initialization
            MigrationStage.custom(
                fromVersion: SchemaV5.self,
                toVersion: SchemaV6.self,
                willMigrate: nil,
                didMigrate: { context in
                    // No data transformation needed - just adding new models and relationship
                    // SDMealLog and SDMealLogItem tables will be created empty
                    // SDUserProfile.mealLogs relationship will be initialized as nil/empty array
                    print(
                        "PersistenceMigrationPlan: Completed migration from V5 to V6 (added SDMealLog and SDMealLogItem for nutrition logging)"
                    )
                    try context.save()
                }
            ),
            // V6 to V7: Add foodType field to SDMealLogItem for food type classification
            // Uses lightweight migration since:
            // 1. Only adding a new field (foodType) to existing SDMealLogItem model
            // 2. Default value "food" is provided for existing records
            // 3. All models with SDUserProfile relationships are redefined for type compatibility
            // 4. No data transformation needed
            MigrationStage.lightweight(
                fromVersion: SchemaV6.self,
                toVersion: SchemaV7.self
            ),
            // V7 to V8: Split quantity field into separate quantity (Double) and unit (String) fields
            // Uses lightweight migration since:
            // 1. Changing quantity from String to Double and adding unit field
            // 2. Default values provided (quantity: 0.0, unit: "")
            // 3. Existing V7 data will have empty/default values (acceptable since meal logs are read-only after processing)
            // 4. New data from backend will use correct structure immediately
            // 5. Water tracking relies on new backend data, not old local data
            // 6. All models redefined for SchemaV8 compatibility
            MigrationStage.lightweight(
                fromVersion: SchemaV7.self,
                toVersion: SchemaV8.self
            ),
            // V8 to V9: Add SDHydrationEntry model for water intake tracking
            // Uses lightweight migration since SDHydrationEntry is standalone with no relationships
            MigrationStage.lightweight(
                fromVersion: SchemaV8.self,
                toVersion: SchemaV9.self
            ),
            // V9 to V10: Add SDWorkout model for workout tracking from HealthKit
            // Uses CUSTOM migration (not lightweight) because:
            // 1. SwiftData has ambiguous keypath resolution between V9 and V10 models
            // 2. All models with relationships to SDUserProfile are redefined in V10
            // 3. SDDietaryAndActivityPreferences redefined to reference SDUserProfileV10
            // 4. Need to ensure proper relationship metadata is updated in the store
            // 5. Lightweight migration fails with "KeyPath does not appear to relate" error
            // 6. Custom migration forces proper schema update and relationship resolution
            // Note: SDSleepSession fields maintained for compatibility (date, startTime, endTime)
            MigrationStage.custom(
                fromVersion: SchemaV9.self,
                toVersion: SchemaV10.self,
                willMigrate: nil,
                didMigrate: { context in
                    // Force schema update by saving context
                    // This ensures all relationship metadata is properly updated to V10
                    // No data transformation needed - SDSleepSession fields remain compatible
                    print(
                        "PersistenceMigrationPlan: Completed migration from V9 to V10 (added SDWorkout, fixed relationship metadata, maintained field compatibility)"
                    )
                    try context.save()
                }
            ),
            // V10 to V11: Add SDWorkoutTemplate and SDTemplateExercise models for workout template management
            // Uses CUSTOM migration (not lightweight) because:
            // 1. Adding new relationship (workoutTemplates) to existing SDUserProfileV10 model
            // 2. SDUserProfileV11 redefines id without unique constraint for CloudKit compatibility
            // 3. All models with relationships to SDUserProfile are redefined in V11
            // 4. Need to ensure proper relationship metadata is updated in the store
            MigrationStage.custom(
                fromVersion: SchemaV10.self,
                toVersion: SchemaV11.self,
                willMigrate: nil,
                didMigrate: { context in
                    // Force schema update by saving context
                    // This ensures all relationship metadata is properly updated to V11
                    // No data transformation needed - just adding new models and relationship
                    print(
                        "PersistenceMigrationPlan: Completed migration from V10 to V11 (added SDWorkoutTemplate and SDTemplateExercise for workout template management)"
                    )
                    try context.save()
                }
            ),
        ]
    }
}
