import SwiftUI

struct ConsultantQuickSelectSheet: View {
    @Bindable var viewModel: CoachViewModel
    @Binding var isShowingSelect: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    
                    Text("Start a new session")
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding([.top, .horizontal])

                    Text("Select a focus area to start a new coaching session. Your session will immediately begin with an **AI Triage** agent.")
                        .font(.subheadline)
                        .padding(.horizontal)
                        .padding(.top, 5)
                        .padding(.bottom, 15)

                    // Card List
                    ForEach(ConsultantType.allCases, id: \.self) { type in
                        ConsultantSelectCard(type: type) {
                            isShowingSelect = false
                            viewModel.startNewConsultation(type: type)
                        }
                    }
                    Spacer()
                }
            }
            .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
            .navigationTitle("Coaching")
            .navigationBarItems(trailing: Button(L10n.Common.cancel) {
                isShowingSelect = false
            })
        }
    }
}


struct ConsultantSelectCard: View {
    let type: ConsultantType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: type.systemIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(type.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    switch type {
                    case .nutritionist:
                        Text("Analyze meals, track macros, and build diet plans.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .fitnessCoach:
                        Text("Create workouts, track reps, and improve training technique.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .wellness:
                        Text("Practice mindful check-ins and receive coping strategies.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .unsure:
                        Text("Start a general conversation to clarify your needs.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(15)
        }
        .buttonStyle(.plain)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
