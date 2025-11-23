import SwiftUI

struct ConsultationDossierView: View {
    
    @Bindable var viewModel: CoachViewModel
    @Binding var isShowingSelect: Bool
    
    @State private var showingGoalSettings: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    
                    // NEW: Goals Management Card, replacing the toolbar button
                    Button {
                        showingGoalSettings = true
                    } label: {
                        ActionCardContent(
                            title: "Manage Goals", // Changed from L10n.Goals.daily
                            icon: "target",
                            color: .ascendBlue
                        )
                    }
                    .buttonStyle(.plain) // Ensure the button doesn't get default button styling
                    .padding(.horizontal) // Apply horizontal padding to align with other content
                    .padding(.top, 10) // Padding from the top of the ScrollView
                    
                    // NEW: Divider between the goals card and the rest of the content
                    Divider()
                        .padding(.horizontal)
                        .padding(.vertical, 5) // Add some vertical spacing around the divider
                    
                    // MARK: - Dossier Content (The Cards)
                    // Added a section title for the artifacts for clarity
                    Text("Past Consultations")
                        .font(.subheadline) // Smaller font size
                        .fontWeight(.semibold) // Semi-bold weight
                        .foregroundColor(.secondary) // System gray color
                        .padding(.horizontal) // Align with other cards/dividers
                        .padding(.top, 5) // Add a little extra top padding
                        .textCase(nil) // Prevent automatic uppercase in some contexts
                    
                    ForEach(viewModel.pastConsultations) { summary in
                        ConsultationCardView(summary: summary, activateAction: viewModel.activateArtifact)
                            .padding(.horizontal) // Ensure consistent horizontal padding for all dossier cards
                            .padding(.vertical, 4) // Adjust vertical padding for consistent row height
                    }
                }
            }
            .navigationTitle("Coach")
            .sheet(isPresented: $showingGoalSettings) {
                GoalSettingsView(viewModel: viewModel)
            }
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        }
    }
}
