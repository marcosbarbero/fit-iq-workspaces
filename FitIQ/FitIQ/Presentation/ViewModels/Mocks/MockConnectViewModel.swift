//
//  MockConnectViewModel.swift
//  FitIQ
//
//  Created by Marcos Barbero on 18/10/2025.
//

import Foundation
// Example Mock State Setup (Goes inside your Preview Provider files)
final class MockConnectViewModel: CoachViewModel {
    
    // 1. Initial State for Dossier (Testing the FAB)
    static func mockDossier() -> CoachViewModel {
        let vm = CoachViewModel()
        vm.currentConsultState = .dossier
        return vm
    }
    
    // 2. State for Goal Discovery View
    static func mockDiscovery() -> CoachViewModel {
        let vm = CoachViewModel()
        // The ConnectView will set this state upon tapping "I'm not sure"
        vm.currentConsultState = .goalDiscovery
        return vm
    }

    // 3. State for Primary Choice View (Needs pre-calculated types)
    static func mockChoiceTriage() -> CoachViewModel {
        let vm = CoachViewModel()
        // Simulate selecting multiple types (Nutritionist, Fitness Coach)
        let selectedTypes: Set<ConsultantType> = [.nutritionist, .fitnessCoach]
        vm.currentConsultState = .choiceTriage(selectedTypes)
        return vm
    }
}
