import Foundation
import SwiftUI

struct AIConsultationChatView: View {
    
    @Bindable var viewModel: CoachViewModel
    let consultantType: ConsultantType
    
    @State private var messageText: String = ""
    
    @Environment(\.colorScheme) var colorScheme
    
    private var cleanSlateBackground: Color {
        return colorScheme == .dark ? .cleanSlateDark : .cleanSlateLight
    }
    
    private var aiAgentName: String { consultantType.aiAgentName }
    private var aiBubbleColor: Color { consultantType.accentColor }
    
    // Simple Mock Messages for simulation
    private var mockMessages: [MockMessage] {
        let disclosureString = "Hello! I'm your \(aiAgentName). This is a triage session. I can handle most questions, but if you need a human, just ask me to **'connect me to a specialist'**."
        
        return [
            MockMessage(text: try! AttributedString(markdown: disclosureString), isUser: false),
            MockMessage(text: try! AttributedString(markdown: "I need a \(consultantType.rawValue) plan for my new life."), isUser: true),
            MockMessage(text: try! AttributedString(markdown: "Understood! Let's start with your current daily routine."), isUser: false),
        ]
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(mockMessages) { message in
                                ChatBubble(
                                    text: message.text,
                                    isUser: message.isUser,
                                    color: message.isUser ? Color(.systemGray3) : aiBubbleColor
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        Spacer(minLength: 0)
                    }
                    .rotationEffect(.degrees(180))
                    .scaleEffect(x: -1, y: 1, anchor: .center)
                    .onAppear {
                        if let lastMessageId = mockMessages.last?.id {
                            proxy.scrollTo(lastMessageId, anchor: .bottom)
                        }
                    }
                }
                .background(cleanSlateBackground.edgesIgnoringSafeArea(.all))
                
                // MARK: - Input Bar
                ChatComposerView(
                    viewModel: viewModel,
                    consultantType: consultantType,
                    messageText: $messageText
                )
            }
            .navigationTitle(consultantType.rawValue)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("End Consult") {
                        viewModel.dismissChat()
                    }
                    .foregroundStyle(Color.attentionOrange)
                }
            }
        }
    }
}

// MARK: - Supporting Chat Components

struct MockMessage: Identifiable {
    let id = UUID().uuidString
    let text: AttributedString
    let isUser: Bool
}

private struct ChatBubble: View {
    let text: AttributedString
    let isUser: Bool
    let color: Color
    
    private var contrastingTextColor: Color {
        guard !isUser else { return .primary }
        return color.isLight() ? .primary : .white
    }
    
    var body: some View {
        HStack {
            if isUser { Spacer() }
            
            Text(text)
                .padding(12)
                .foregroundStyle(isUser ? .primary : contrastingTextColor)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                
            if !isUser { Spacer() }
        }
        .rotationEffect(.degrees(180))
        .scaleEffect(x: -1, y: 1, anchor: .center)
        .padding(.top, 2)
    }
}
