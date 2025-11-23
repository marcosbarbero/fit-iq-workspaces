import SwiftUI

struct CoachView: View {
    
    @State private var viewModel: CoachViewModel
    @State private var isShowingConsultantSelect: Bool = false
    
    init(viewModel: CoachViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        HStack {
            Group {
                switch viewModel.currentConsultState {
                case .dossier:
                    // Main Dossier and FAB
                    ConsultationDossierView(viewModel: viewModel, isShowingSelect: $isShowingConsultantSelect)
                        .overlay(alignment: .bottomTrailing) {
                            ActionFAB(action: {
                                isShowingConsultantSelect = true
                            }, color: .ascendBlue, systemImageName: "message.fill")
                            .padding(.trailing, 20)
                            .padding(.bottom, 10)
                        }
                        .sheet(isPresented: $isShowingConsultantSelect) {
                            // All initial consults start here
                            ConsultantQuickSelectSheet(viewModel: viewModel, isShowingSelect: $isShowingConsultantSelect)
                        }
                    
                case .goalDiscovery:
                    // Triage Step 1: Multi-Select Goals
                    GoalDiscoveryView(viewModel: viewModel)
                    
                case .choiceTriage(let focusAreas):
                    // Triage Step 2: Pick Primary Focus
                    PrimaryChoiceView(viewModel: viewModel, focusAreaSet: focusAreas)
                    
                case .activeChat(let type):
                    // Active Chat Session
                    AIConsultationChatView(viewModel: viewModel, consultantType: type)
                }
            }
        }
    }
}
