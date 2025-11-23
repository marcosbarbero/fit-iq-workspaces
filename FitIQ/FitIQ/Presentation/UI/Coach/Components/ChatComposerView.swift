//
//  ChatComposerView.swift
//  FitIQ
//
//  Created by Marcos Barbero on 18/10/2025.
//

import Foundation
import SwiftUI

// MARK: - Component: ChatComposerView (Final Revision for Contrast)
import SwiftUI

struct ChatComposerView: View {
    @Bindable var viewModel: CoachViewModel
    let consultantType: ConsultantType
    @Binding var messageText: String
    
    @State private var showingAttachmentSheet: Bool = false
    
    private var accentColor: Color { consultantType.accentColor }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        print("Sending message via Return key: \(messageText)")
        messageText = ""
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            
            // 1. Attachment Button (+)
            Button(action: { showingAttachmentSheet = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .foregroundStyle(accentColor)
            }
            
            // 2. Text Input Field (The Pill)
            HStack(spacing: 4) {
                
                TextField("Message...", text: $messageText)
                    .lineLimit(1...5)
                    .foregroundStyle(.primary)
                    .padding(.leading, 8)
                    .onSubmit(sendMessage)
                    .submitLabel(.send)
                
                // Mic Button
                Button(action: {}) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(accentColor)
                        .padding(.leading, 4)
                }
                
                // Camera Button
                Button(action: {}) {
                    Image(systemName: "camera.fill")
                        .foregroundStyle(accentColor)
                        .padding(.trailing, 8)
                }
            }
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .clipShape(Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            }
        }
        .padding([.horizontal, .vertical], 8)
        .background(.ultraThinMaterial)
        
        .sheet(isPresented: $showingAttachmentSheet) {
            AttachmentOptionsSheet()
        }
    }
}


// MARK: - New Sheet: AttachmentOptionsSheet
struct AttachmentOptionsSheet: View {
    var body: some View {
        NavigationView {
            List {
                Section {
                    // Core Nutrition Features
                    AttachmentRow(icon: "photo.fill", title: "Photo/Meal Scan", color: .ascendBlue) { /* Action: Open ImagePicker */ }
                    AttachmentRow(icon: "doc.text.fill", title: "Document/Lab Report", color: .ascendBlue) { /* Action: Open FilePicker */ }
                } header: {
                    Text("Media & Files")
                }
                
                Section {
                    // Future Integration Points
                    AttachmentRow(icon: "figure.walk", title: "Attach Workout", color: .vitalityTeal) { /* Action: Select past workout */ }
                    AttachmentRow(icon: "heart.fill", title: "Attach Vitals Data", color: .serenityLavender) { /* Action: Select HealthKit data */ }
                } header: {
                    Text("Health Data")
                }
            }
            .navigationTitle("Attachments")
            .navigationBarItems(trailing: Button("Done") { /* Dismiss */ })
        }
    }
}
// MARK: - New Component: AttachmentRow
struct AttachmentRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(color)
                    .clipShape(Circle())
                
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
