import SwiftUI

struct GoalSettingsView: View {
    
    @Bindable var viewModel: CoachViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var showingCreationSheet: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.userGoals.isEmpty {
                    ContentUnavailableView("No Goals Defined", systemImage: "target", description: Text("Start by adding a specific goal like a weight target or daily habit."))
                        .listRowBackground(Color.clear)
                } else {
                    Section("Active Goals") {
                        ForEach(viewModel.userGoals) { goal in
                            GoalRowView(goal: goal) // 💡 NEW COMPONENT
                        }
                        // Allows swiping to delete/edit (future implementation)
                        .onDelete { indexSet in
                            // viewModel.deleteGoal(at: indexSet)
                        }
                    }
                    
                    Section("Progress Overview") {
                        // Placeholder for charts/metrics related to goals
                        Text("Goal progress charts coming soon...")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Manage Your Goals")
            .listStyle(.insetGrouped)
            .onAppear {
                viewModel.loadUserGoals() // Load goals when view appears
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button{
                        showingCreationSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.ascendBlue)
                    }
                
                }
            }
        }
        .sheet(isPresented: $showingCreationSheet) {
            GoalCreationSheet(viewModel: viewModel)
        }
    }
}
