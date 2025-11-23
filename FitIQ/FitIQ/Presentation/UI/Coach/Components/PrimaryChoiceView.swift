import SwiftUI

struct PrimaryChoiceView: View {
    @Bindable var viewModel: CoachViewModel
    let focusAreas: [ConsultantType]
    
    init(viewModel: CoachViewModel, focusAreaSet: Set<ConsultantType>) {
        self.viewModel = viewModel
        self.focusAreas = Array(focusAreaSet).sorted { $0.rawValue < $1.rawValue }
    }
    
    var body: some View {
        VStack(spacing: 40) {
            
            VStack(spacing: 10) {
                Image(systemName: "figure.mind.and.body")
                    .font(.largeTitle)
                    .foregroundStyle(Color.ascendBlue)
                
                Text("Your Goal Requires Multiple Focus Areas!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("We are setting up your specialized consultation channels. Which area would you like to jump into **first**?")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 40)
            
            // MARK: - Choice Buttons
            VStack(spacing: 16) {
                ForEach(focusAreas, id: \.self) { type in
                    ConsultantSelectCard(type: type) {
                        viewModel.choosePrimaryFocus(type: type)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Go Back") {
                    viewModel.dismissChat()
                }
            }
        }
    }
}
