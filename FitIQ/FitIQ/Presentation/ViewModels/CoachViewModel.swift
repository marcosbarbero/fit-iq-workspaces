import Foundation
import SwiftUI

extension TriageGoal {
    static var mockUserGoals: [TriageGoal] = [
        // Updated mock goals to include the new properties
        TriageGoal(
            title: "Lose 5kg by Christmas",
            mappedTypes: [.nutritionist, .fitnessCoach],
            targetValue: 5.0, unit: "kg",
            targetDate: Calendar.current.date(from: DateComponents(year: 2024, month: 12, day: 25)),
            source: .aiTriage
        ),
        TriageGoal(
            title: "Workout 3x a week for 3 months",
            mappedTypes: [.fitnessCoach],
            targetValue: 3.0,
            unit: "times/week",
            targetDate: Date().addingTimeInterval(86400 * 30 * 3),
            source: .declarative
        ),
        TriageGoal(
            title: "No alcohol intake for 40 days",
            mappedTypes: [.nutritionist, .wellness],
            targetValue: 0.0, unit: "days",
            targetDate: Date().addingTimeInterval(86400 * 40),
            source: .professional
        ),
    ]
    // NOTE: In a real app, TriageGoal would need targetDate and unit properties. -- This comment is now addressed by the changes to TriageGoal.
}

@Observable
class CoachViewModel {
    
    var currentConsultState: ConsultationState = .dossier
    var pastConsultations: [ConsultationSummary] = ConsultationSummary.mockData
    
    // Holds the user's declared goals for display in the GoalSettingsView
    var userGoals: [TriageGoal] = TriageGoal.mockUserGoals // 💡 NEW PROPERTY (needs mock data)

    // 💡 NEW ACTION: Triggers the Use Case to create a new goal artifact
    func createDeclarativeGoal(title: String, targetValue: Double, unit: String, date: Date) {
        // This simulates calling the Domain UseCase and updating the local list immediately.
        
        let newGoal = TriageGoal(
            title: title,
            mappedTypes: [.nutritionist, .fitnessCoach], // Placeholder mapping
            targetValue: targetValue, // Pass the new targetValue
            unit: unit,               // Pass the new unit
            targetDate: date,
            source: .declarative
        )
        
        // 1. Live UI Update: Add placeholder goal to the list immediately
        userGoals.append(newGoal)
        
        // 2. Event is published to trigger background AI processing
        print("Goal created locally: \(title). Event published for AI synthesis.")
    }
    
    // 💡 NEW ACTION: Simulates fetching goals from the Domain/Persistence
    func loadUserGoals() {
        // Simulates loading the TriageGoals from the ConsultationGroup entity
        // For now, load mock data:
        self.userGoals = TriageGoal.mockUserGoals
    }
    
    init(initialState: ConsultationState = .dossier) {
        self.currentConsultState = initialState
        // ... load mock data here ...
    }
    // MARK: - Actions (UI-Driven)
    
    func startNewConsultation(type: ConsultantType) {
        if type == .unsure {
            self.currentConsultState = .goalDiscovery // Enter the multi-select flow
        } else {
            self.currentConsultState = .activeChat(type) // Start specific chat directly
        }
    }
    
    func dismissChat() {
        self.currentConsultState = .dossier
    }
    
    func activateArtifact(_ artifactID: String) {
        guard let index = pastConsultations.firstIndex(where: { $0.id == artifactID }) else { return }
        
        // UX Logic: Deactivate the previously active plan of the same type (simulated).
        pastConsultations
            .filter { $0.consultant == pastConsultations[index].consultant }
            .forEach { summary in
                if let i = pastConsultations.firstIndex(where: { $0.id == summary.id }) {
                    pastConsultations[i].isActive = false
                }
            }
        
        // Activate the selected plan
        pastConsultations[index].isActive = true
    }
    
    func submitGoals(goals: Set<TriageGoal>) {
        let selectedTypes = goals.reduce(into: Set<ConsultantType>()) { result, goal in
            result.formUnion(goal.mappedTypes)
        }
        
        if selectedTypes.count == 0 {
            // No goals selected, stay on discovery screen (or show error)
            return
        }
        
        if selectedTypes.count == 1, let singleType = selectedTypes.first {
            // Only one focus area selected, start chat directly
            self.currentConsultState = .activeChat(singleType)
        } else {
            // Multiple focus areas selected, move to the Choice Triage step
            self.currentConsultState = .choiceTriage(selectedTypes)
        }
    }
    
    func choosePrimaryFocus(type: ConsultantType) {
        // This is the final step, now transition to the actual chat
        self.currentConsultState = .activeChat(type)
        // NOTE: In a full app, this would trigger the CreateParallelConsultationsUseCase
    }
}

// MARK: - Supporting Types (for Presentation)

enum ConsultationState {
    case dossier
    case activeChat(ConsultantType)
    case goalDiscovery // Multi-select phase
    case choiceTriage(Set<ConsultantType>) // Pick primary focus
}

import SwiftUI // Required for Color

enum ConsultantType: String, CaseIterable, Identifiable, Codable { // Added Codable conformance
    case nutritionist = "Nutritionist"
    case fitnessCoach = "Fitness Coach"
    case wellness = "Wellness Specialist"
    case unsure = "I'm not sure"

    var id: String { self.rawValue }

    var systemIcon: String {
        switch self {
        case .nutritionist: return "leaf.fill"
        case .fitnessCoach: return "figure.strengthtraining.traditional"
        case .wellness: return "brain.head.profile"
        case .unsure: return "questionmark.circle.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .nutritionist: return .ascendBlue       // Primary/Trust
        case .fitnessCoach: return .vitalityTeal     // Fitness/Energy
        case .wellness: return .serenityLavender   // Wellness/Calm
        case .unsure: return Color(.systemGray)      // Neutral/General
        }
    }
    
    /// The specific AI Agent name for the triage/chat session.
    var aiAgentName: String {
        switch self {
        case .nutritionist: return "Nutrition AI"
        case .fitnessCoach: return "Fitness AI"
        case .wellness: return "Wellness AI"
        case .unsure: return "General AI"
        }
    }
}

// ConnectViewModel.swift

// MARK: - Mock Data (Placeholder for Domain Entities)

struct ConsultationSummary: Identifiable {
    let id = UUID().uuidString
    let date: Date
    let consultant: ConsultantType // Uses the updated enum
    let artifactTitle: String
    var isActive: Bool
    
    static var mockData: [ConsultationSummary] {
        [
            ConsultationSummary(
                date: Date().addingTimeInterval(-86400 * 3),
                consultant: .nutritionist, // Was .aiNutritionist
                artifactTitle: "7-Day Low Carb Plan (v1)",
                isActive: true
            ),
            
            ConsultationSummary(
                date: Date().addingTimeInterval(-86400 * 10),
                consultant: .fitnessCoach, // Was .aiTrainer
                artifactTitle: "3-Day Full Body Hypertrophy",
                isActive: false
            ),
            
            ConsultationSummary(
                date: Date().addingTimeInterval(-86400 * 25),
                consultant: .wellness, // Was .humanSpecialist
                artifactTitle: "Mindfulness & Sleep Strategy",
                isActive: false
            )
        ]
    }
}
