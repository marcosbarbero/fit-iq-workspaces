////
////  AIChatView.swift
////  FitIQ
////
////  Created by Marcos Barbero on 18/10/2025.
////
//
//import Foundation
//import SwiftUI
//
//// We assume the helper structs like MessageBubble, StructuredContentCard, etc., are available.
//
//struct AIChatView: View {
//    @Bindable var viewModel: ConnectViewModel
//    let currentThread: Thread
//    
//    @FocusState private var isInputFocused: Bool
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            
//            // MARK: 1. Chat Message Area
//            ChatScrollView(messages: viewModel.activeChatMessages, isAITyping: viewModel.isAITyping)
//                .background(Color(.systemGroupedBackground))
//
//            // MARK: 2. Input Bar (Always at the bottom)
//            ChatInputBar(
//                input: $viewModel.currentInput,
//                isAITyping: viewModel.isAITyping,
//                onSend: { Task { await viewModel.sendUserMessage() } }
//            )
//            .focused($isInputFocused)
//            .padding(.bottom, 8)
//            .background(Color(.systemBackground))
//        }
//        .navigationTitle(currentThread.name)
//        .navigationBarTitleDisplayMode(.inline)
//        // Added toolbar to link to the professional's profile/settings (if human)
//        .toolbar {
//            ToolbarItem(placement: .topBarTrailing) {
//                Button { print("Viewing Profile/Settings for \(currentThread.name)") } label: {
//                    Image(systemName: "info.circle")
//                }
//            }
//        }
//    }
//}
