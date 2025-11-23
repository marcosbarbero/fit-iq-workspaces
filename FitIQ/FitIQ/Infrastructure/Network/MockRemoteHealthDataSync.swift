// MockRemoteHealthDataSync.swift
import Foundation

//class MockRemoteHealthDataSync: RemoteHealthDataSyncPort {
//    func uploadBodyMass(kg: Double, date: Date, for userProfileID: UUID, localID: UUID?) async throws -> String? {
//        print("MockRemoteSync: Uploading body mass \(kg) kg for \(userProfileID) (Local ID: \(localID?.uuidString ?? "N/A"))")
//        // Simulate a backend ID
//        return "backend-bodymass-\(UUID().uuidString)"
//    }
//    
//    func uploadHeight(cm: Double, date: Date, for userProfileID: UUID, localID: UUID?) async throws -> String? {
//        print("MockRemoteSync: Uploading height \(cm) cm for \(userProfileID) (Local ID: \(localID?.uuidString ?? "N/A"))")
//        // Simulate a backend ID
//        return "backend-height-\(UUID().uuidString)"
//    }
//    
//    func uploadActivitySnapshot(snapshot: ActivitySnapshot, for userProfileID: UUID) async throws -> String? {
//        print("MockRemoteSync: Uploading activity snapshot for user \(userProfileID) on date \(snapshot.date). Steps: \(snapshot.steps ?? 0) (Local ID: \(snapshot.id.uuidString))")
//        // Simulate a backend ID
//        return "backend-snapshot-\(UUID().uuidString)"
//    }
//}

