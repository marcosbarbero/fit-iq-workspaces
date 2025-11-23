//
//  HealthMetricsSnapshot.swift
//  FitIQ
//
//  Created by Marcos Barbero on 14/10/2025.
//

import Foundation
import HealthKit

struct HealthMetricsSnapshot {
    let date: Date
    let weightKg: Double?
    let heightCm: Double?
    let bmi: Double?
    let dateOfBirth: Date?
    let biologicalSex: String?
}

extension HKBiologicalSex {
    func hkSexToString() -> String? {
        switch self {
        case .female: return "Female"
        case .male: return "Male"
        case .other: return "Other"
        case .notSet: return nil
        @unknown default: return nil
        }
    }
}
