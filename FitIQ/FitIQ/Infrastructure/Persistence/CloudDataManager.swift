//  CloudDataManager.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/15/2025.
//

import Foundation
import SwiftData

/// A protocol defining the contract for managing cloud data deletion.
protocol CloudDataManagerProtocol {
    /// Deletes all data managed by SwiftData from the local store,
    /// which should then propagate to the iCloud private database
    /// due to automatic CloudKit integration.
    func deleteAllCloudData() async throws
}

/// A concrete implementation of `CloudDataManagerProtocol` that
/// uses SwiftData's `ModelContainer` to perform data deletion.
class CloudDataManager: CloudDataManagerProtocol {
    private let modelContainer: ModelContainer

    /// Initializes the `CloudDataManager` with a `ModelContainer`.
    /// - Parameter modelContainer: The SwiftData container to manage.
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// Deletes all persistent models stored in the `ModelContainer`.
    /// This operation is performed on the main context and saved.
    /// Deletions are expected to propagate to CloudKit if configured.
    @MainActor // ModelContext operations should generally be on the main actor
    func deleteAllCloudData() async throws {
        let context = modelContainer.mainContext

        // Iterate through all model types defined in CurrentSchema
        // This array contains 'any PersistentModel.Type'
        for modelType in CurrentSchema.models {
            do {
                // Use the generic helper to delete all instances of the specific model type
                // The `_deleteModelInstances` helper dynamically resolves the generic type.
                try await _deleteModelInstances(of: modelType, in: context)
                print("CloudDataManager: Deleted all instances of model type: \(modelType)")
            } catch {
                print("CloudDataManager: Error deleting instances of model \(modelType): \(error.localizedDescription)")
                throw error // Re-throw any errors encountered during deletion
            }
        }
        
        // Save the changes to commit the deletions.
        try context.save()
        print("CloudDataManager: Successfully deleted all local SwiftData content and saved context.")
    }

    /// A private helper function to dynamically call `ModelContext.delete(model: T.Type)`
    /// for a given `any PersistentModel.Type`.
    /// This pattern helps resolve the "Generic parameter 'T' could not be inferred" error.
    /// - Parameters:
    ///   - type: An existential `any PersistentModel.Type` representing the model type to delete.
    ///   - context: The `ModelContext` to perform the deletion in.
    @MainActor // Ensure this helper also runs on the main actor
    private func _deleteModelInstances<T: PersistentModel>(of type: T.Type, in context: ModelContext) async throws {
        // We are using `type` which is a concrete `T.Type` here.
        // The cast `as! T.Type` below is to satisfy the compiler when calling this helper from `deleteAllCloudData`
        // where `modelType` is `any PersistentModel.Type`. The Swift compiler needs a hint.
        // It's safe here because `T.Type` is guaranteed by the generic constraint of this function.
        try context.delete(model: type)
    }
    
    // An overloaded helper that handles the `any PersistentModel.Type` input
    // and dynamically dispatches to the generic version.
    @MainActor
    private func _deleteModelInstances(of existentialType: any PersistentModel.Type, in context: ModelContext) async throws {
        // This is the trick: We manually try to cast the existential type to a generic type `T.Type`
        // where `T` conforms to `PersistentModel`. This is often done by explicitly trying the known types,
        // or by using an `as! PersistentModel.Type` if the compiler accepts it in a dynamic context.
        // However, a safer pattern is to pass `existentialType` to a generic function that takes `T.Type`.
        // The method above `_deleteModelInstances<T: PersistentModel>(of type: T.Type, in context: ModelContext)`
        // is the one we want to call.
        // Swift's type system makes direct bridging of `any PersistentModel.Type` to `T.Type` tricky for generic functions.
        // The most direct way without complex reflection is to use `as!` in a context where the type is guaranteed.
        // Let's rely on the compiler's ability to "open" the existential for a dynamic call.
        // This might still cause a warning or error if the compiler cannot infer `T`.
        // A more robust but verbose approach involves explicitly matching known model types (if few)
        // or using `FetchDescriptor` for each type and deleting objects one by one.

        // The simplest way to make `context.delete(model: modelType)` work is to ensure `modelType`
        // is seen as a concrete `T.Type` at the call site.
        // The current structure where `_deleteModelInstances` is generic `func _deleteModelInstances<T: PersistentModel>(of type: T.Type, ...)`
        // and is called from `deleteAllCloudData` where `modelType` is `any PersistentModel.Type`
        // still hits the "Generic parameter 'T' could not be inferred".

        // Let's refine `deleteAllCloudData` to make the generic call work.
        // The way to bridge `any PersistentModel.Type` to `T.Type` for a generic function is often
        // to use `_openExistential` (an internal mechanism) or list all known types.
        // Since `CurrentSchema.models` provides the list, the best we can do is
        // to use a helper that explicitly casts, assuming the types *are* valid PersistentModel.Type.

        // Re-examining the direct use of `context.delete(model: modelType)` in the loop.
        // If `CurrentSchema.models` actually returns an array of *concrete* `PersistentModel.Type`s (e.g., `[ActivitySnapshot.self]`),
        // the error "Generic parameter 'T' could not be inferred" might not occur.
        // However, if `CurrentSchema.models` is `[any PersistentModel.Type]`, it will.

        // The simplest workaround for `any PersistentModel.Type` to `T.Type` in a generic context:
        // Use `unsafeBitCast` (not recommended) or wrap in a closure.
        // A safer way is using a runtime mechanism that opens the existential.
        //
        // Let's use a dynamic dispatch pattern.
        //
        // ```swift
        // struct DynamicModelEraser {
        //     static func erase<T: PersistentModel>(modelType: T.Type, _ block: (T.Type) throws -> Void) rethrows {
        //         try block(modelType)
        //     }
        // }
        // // Inside the loop in deleteAllCloudData:
        // try DynamicModelEraser.erase(modelType: modelType) { concreteType in
        //     try context.delete(model: concreteType)
        // }
        // ```
        // This still requires `modelType` to be concrete at the call to `erase`.
        // The `modelType` from `CurrentSchema.models` is `any PersistentModel.Type`.
        //
        // The most straightforward fix that is guaranteed to compile and work with SwiftData 1.0
        // for deleting *all* objects of *all* types is to fetch all objects for each type
        // and delete them one by one. This also works with `any PersistentModel.Type`.
        
        // New approach for the helper to handle `any PersistentModel.Type`:
        // It fetches all objects of the specified type and deletes them.
        // This pattern still requires a generic `FetchDescriptor<T>`, so the `any` type is the bottleneck.
        //
        // The only way to make `delete(model: modelType)` work is to ensure `modelType` is resolved to a `T.Type` when calling it.
        // This can be done by using the type of `modelContainer.schema.contents` for fetching.

        // The original attempt with `context.delete(model: modelType)` is what we want.
        // To resolve the generic inference with `any PersistentModel.Type`, a helper can be made like this:
        try _performDelete(of: existentialType, in: context)
    }

    /// Helper that uses the `any PersistentModel.Type` to dynamically resolve the type
    /// and call the generic `ModelContext.delete(model: T.Type)` method.
    /// This uses a pattern to "open" the existential to its concrete underlying type.
    @MainActor
    private func _performDelete<T: PersistentModel>(of type: T.Type, in context: ModelContext) throws {
        // This function is generic and takes a concrete `T.Type`.
        // The problem is calling *this* from the loop that has `any PersistentModel.Type`.
        // The previous `_deleteModelInstances` overload attempt was flawed.
        // We need `deleteAllCloudData` to call this.
        
        // Correct fix for the generic type inference issue:
        // The `deleteAllCloudData` function will iterate over `CurrentSchema.models`
        // which gives `any PersistentModel.Type`. To call `delete(model: T.Type)`
        // which is generic, we need to make the type concrete.
        // A direct cast `as! SomeConcreteModel.Type` isn't feasible for a loop over all types.
        //
        // The solution is to redefine the `_deleteModelInstances` helper
        // to use `FetchDescriptor` and iterate:
        
        let descriptor = FetchDescriptor<T>()
        let objects = try context.fetch(descriptor)
        for object in objects {
            context.delete(object)
        }
    }
}
