////
////  ChatScrollView.swift
////  FitIQ
////
////  Created by Marcos Barbero on 18/10/2025.
////
//
//import Foundation
//import SwiftUI
//
//// MARK: - Chat Scroll View Helpers
//
//struct ChatScrollView: View {
//    let messages: [ChatMessage]
//    let isAITyping: Bool
//    
//    var body: some View {
//        ScrollViewReader { proxy in
//            ScrollView {
//                VStack(alignment: .leading, spacing: 10) {
//                    ForEach(messages) { message in
//                        MessageBubble(message: message)
//                            .id(message.id)
//                    }
//                    if isAITyping {
//                        AITypingIndicator()
//                    }
//                }
//                .padding(.horizontal)
//                .padding(.top, 10)
//            }
//            .onAppear {
//                // Scroll to the latest message on load
//                if let lastMessage = messages.last {
//                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
//                }
//            }
//            .onChange(of: messages.count) {
//                // Scroll to the bottom when a new message arrives
//                if let lastMessage = messages.last {
//                    withAnimation {
//                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
//                    }
//                }
//            }
//        }
//    }
//}
//
//struct MessageBubble: View {
//    let message: ChatMessage
//    
//    private var isUser: Bool { message.source == .user }
//        private var bgColor: Color { isUser ? Color.ascendBlue : Color(.systemGray5) }
//        private var textColor: Color { isUser ? .white : .primary }
//        private var alignment: Alignment { isUser ? .trailing : .leading }
//    
//        var body: some View {
//            HStack {
//                if isUser { Spacer() }
//            
//                VStack(alignment: isUser ? .trailing : .leading, spacing: 5) {
//                
//                    // 1. Structured Content Card (HIGH POLISH)
//                    if let card = message.structuredContent {
//                        StructuredContentCard(card: card)
//                            .padding(.bottom, 5)
//                            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2) // Subtle lift
//                    }
//                
//                    // 2. Text Content
//                    Text(message.text)
//                        .padding(10)
//                        .background(bgColor)
//                        .foregroundColor(textColor)
//                        // Ensure the corner radius logic is correct (assuming the extension is fixed)
//                        .cornerRadius(12, corners: isUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
//                }
//                .frame(maxWidth: 300, alignment: alignment)
//            
//            if !isUser { Spacer() }
//        }
//    }
//}
//
//struct StructuredContentCard: View {
//    let card: StructuredContent
//    
//    // We use the card's color to theme the design
//    var body: some View {
//        VStack(alignment: .leading, spacing: 10) {
//            
//            // Header: Icon, Title, and Type
//            HStack {
//                Image(systemName: card.type == "GoalStatus" ? "target" : "figure.walk.circle.fill")
//                    .foregroundColor(card.color)
//                Text(card.title)
//                    .font(.subheadline)
//                    .fontWeight(.heavy)
//                Spacer()
//                Text(card.type).font(.caption2).foregroundColor(.secondary)
//            }
//            
//            Divider()
//            
//            // Detail Metrics
//            Text(card.detail)
//                .font(.callout)
//                .foregroundColor(.primary)
//                .lineLimit(nil) // Allow full detail viewing
//            
//            // Action Link
//            HStack {
//                Text("View Full Report")
//                Image(systemName: "arrow.forward.circle.fill")
//            }
//            .font(.caption)
//            .fontWeight(.semibold)
//            .foregroundColor(card.color)
//        }
//        .padding(12)
//        .background(Color(.systemBackground)) // Use clean white/dark mode background for contrast
//        .cornerRadius(10)
//        .overlay(
//            RoundedRectangle(cornerRadius: 10)
//                .stroke(card.color.opacity(0.5), lineWidth: 1) // Themed border
//        )
//    }
//}
//
//struct AITypingIndicator: View {
//    var body: some View {
//        HStack {
//            ProgressView()
//            Text("AI Companion is typing...")
//                .font(.caption)
//                .foregroundColor(.secondary)
//        }
//        .padding(.leading, 10)
//    }
//}
