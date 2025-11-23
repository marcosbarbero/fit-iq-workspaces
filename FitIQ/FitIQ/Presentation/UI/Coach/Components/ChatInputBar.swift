//
//  ChatInputBar.swift
//  FitIQ
//
//  Created by Marcos Barbero on 18/10/2025.
//

import Foundation
import SwiftUI

// MARK: - Chat Input Bar

struct ChatInputBar: View {
    @Binding var input: String
    let isAITyping: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack {
            TextField("Ask the AI Companion...", text: $input, axis: .vertical)
                .textFieldStyle(.plain)
                .frame(minHeight: 30)
                .padding(.horizontal, 10)
                .background(Color(.systemGray6))
                .cornerRadius(15)
            
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
            }
            // Logic to disable the button when input is empty or AI is busy
            .tint(input.isEmpty || isAITyping ? .gray : .ascendBlue)
            .disabled(input.isEmpty || isAITyping)
        }
        .padding(.horizontal)
    }
}
