//
//  OnboardingViewModel.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

import Foundation
import Combine

class OnboardingSetupViewModel: ObservableObject {
    let healthKitAuthUseCase: RequestHealthKitAuthorizationUseCase
    
    init(healthKitAuthUseCase: RequestHealthKitAuthorizationUseCase) {
        self.healthKitAuthUseCase = healthKitAuthUseCase
    }
    
    func requestHealthKitAuthorization() async {
        try? await self.healthKitAuthUseCase.execute()
    }
        
}
