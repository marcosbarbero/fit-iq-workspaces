// MockLocalHealthDataStore.swift
import Foundation

class MockLocalHealthDataStore {
    func saveBodyMass(kg: Double, date: Date, for userProfileID: UUID) async throws {
        print("MockLocalDataStore: Saving body mass \(kg) kg for \(userProfileID)")
    }
    
    func saveHeight(cm: Double, date: Date, for userProfileID: UUID) async throws {
        print("MockLocalDataStore: Saving height \(cm) cm for \(userProfileID)")
    }
    
    func saveStepCount(steps: Double, date: Date, for userProfileID: UUID) async throws {
        print("MockLocalDataStore: Saving step count \(Int(steps)) steps for \(userProfileID)")
    }
    
    func saveBasalEnergyBurned(kcal: Double, date: Date, for userProfileID: UUID) async throws {
        print("MockLocalDataStore: Saving basal energy \(Int(kcal)) kcal for \(userProfileID)")
    }
    
    func saveActiveEnergyBurned(kcal: Double, date: Date, for userProfileID: UUID) async throws {
        print("MockLocalDataStore: Saving active energy \(Int(kcal)) kcal for \(userProfileID)")
    }
}
