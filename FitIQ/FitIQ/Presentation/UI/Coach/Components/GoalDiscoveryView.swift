import SwiftUI

struct GoalDiscoveryView: View {
    
    @Bindable var viewModel: CoachViewModel
    @State private var selectedGoals: Set<TriageGoal> = []
    
    private let allGoals = TriageGoal.allGoals
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        Text("Tell us about your goals.")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        Text("Select all the areas you want to prioritize right now. We'll use this to create your personalized consultation channels.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        // MARK: - Goal Selection List
                        VStack(spacing: 12) {
                            ForEach(allGoals, id: \.self) { goal in
                                GoalCheckboxCard(goal: goal, isSelected: selectedGoals.contains(goal)) {
                                    if selectedGoals.contains(goal) {
                                        selectedGoals.remove(goal)
                                    } else {
                                        selectedGoals.insert(goal)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    .padding(.top, 20)
                }
                
                // MARK: - Continue Button (Floating Footer)
                Button("Continue: Analyze My Goals") {
                    viewModel.submitGoals(goals: selectedGoals)
                }
                .buttonStyle(.borderedProminent)
                .tint(.ascendBlue)
                .controlSize(.large)
                .disabled(selectedGoals.isEmpty)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
            .navigationTitle("Goal Discovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { viewModel.dismissChat() }
                }
            }
        }
    }
}
