//
//  SchemaDefinition.swift
//
//  Created by Marcos Barbero on 28/09/2025.
//
import Foundation
import SwiftData

// Use an alias to refer to the active schema for the main app container
typealias CurrentSchema = SchemaV11

// List all historical schema versions
enum FitIQSchemaDefinitition: CaseIterable {
    case v1
    case v2
    case v3
    case v4
    case v5
    case v6
    case v7
    case v8
    case v9
    case v10
    case v11

    var schema: any VersionedSchema.Type {
        switch self {
        case .v1: return SchemaV1.self
        case .v2: return SchemaV2.self
        case .v3: return SchemaV3.self
        case .v4: return SchemaV4.self
        case .v5: return SchemaV5.self
        case .v6: return SchemaV6.self
        case .v7: return SchemaV7.self
        case .v8: return SchemaV8.self
        case .v9: return SchemaV9.self
        case .v10: return SchemaV10.self
        case .v11: return SchemaV11.self
        @unknown default: return CurrentSchema.self
        }
    }
}
