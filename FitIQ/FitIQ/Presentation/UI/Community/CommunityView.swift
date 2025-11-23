//
//  CommunityView.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

import Foundation
import SwiftUI

// NOTE: Color extensions (ascendBlue, vitalityTeal, serenityLavender, etc.) must be available.

// MARK: - Mock Data Models

enum PostType: String, CaseIterable, Identifiable {
    case workout, meal, mood, achievement

    var id: String { self.rawValue } // Added to conform to Identifiable
}

struct CommunityPost: Identifiable {
    let id = UUID()
    let user: String
    let time: String
    let type: PostType
    let caption: String
    let imageUrl: String? // Placeholder for meal/workout photo
    
    var accentColor: Color {
        switch type {
        case .workout, .achievement: return .vitalityTeal // Activity/Goal Color
        case .meal: return .ascendBlue // Nutrition/Data Color
        case .mood: return .serenityLavender // Wellness Color
        }
    }
}

extension CommunityPost {
    static let mockData: [CommunityPost] = [
        CommunityPost(user: "fit_marco", time: "2h ago", type: .workout,
                      caption: "Just crushed a 60 min full-body circuit! Feeling the burn 🔥 #FitIQ",
                      imageUrl: "https://placehold.co/600x400/00C896/ffffff?text=WORKOUT_PIC"),
        CommunityPost(user: "wellness_jen", time: "5h ago", type: .mood,
                      caption: "Needed a slow morning. Logged 10 min of deep breathing. Take care of your mind today. ✨",
                      imageUrl: nil),
        CommunityPost(user: "ai_nutritionist", time: "1d ago", type: .meal,
                      caption: "Macro check: Perfect post-workout smoothie! Don't forget your protein intake goals.",
                      imageUrl: "https://placehold.co/600x400/007AFF/ffffff?text=MEAL_PIC"),
        CommunityPost(user: "goal_getter", time: "2d ago", type: .achievement,
                      caption: "Hit my 10,000 steps streak for the whole week! Small wins are big motivation!",
                      imageUrl: nil)
    ]
}

// MARK: - Main View

struct CommunityView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Header for New Post CTA
                    QuickPostCTA()
                        .padding(.top, 10)
                    
                    ForEach(CommunityPost.mockData) { post in
                        CommunityPostRow(post: post)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 10)
            }
            .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
            .navigationTitle("Community Feed")
        }
    }
}

// MARK: - Helper Views

struct QuickPostCTA: View {
    var body: some View {
        Button {
            print("Open New Post Composer")
        } label: {
            HStack {
                Image(systemName: "square.and.pencil")
                Text("Share your workout, meal, or thoughts")
                Spacer()
                Image(systemName: "arrow.right")
            }
            .padding(15)
            .background(Color(.secondarySystemBackground))
            .foregroundColor(.secondary)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
        .padding(.horizontal)
    }
}

struct CommunityPostRow: View {
    let post: CommunityPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            
            // Post Header (User + Type Badge)
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading) {
                    Text(post.user)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("\(post.time) | \(post.type.rawValue.capitalized)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Accent Badge
                Text(post.type == .achievement ? "ACHIEVEMENT" : post.type.rawValue.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(post.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(5)
            }
            
            // Image Content
            if let urlString = post.imageUrl, let url = URL(string: urlString) {
                // Mock Image Placeholder
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemFill))
                        .frame(height: 200)
                        .overlay(Text("Loading Image..."))
                }
                .frame(maxHeight: 200)
                .cornerRadius(8)
                .clipped()
                .padding(.vertical, 5)
            }
            
            // Caption
            Text(post.caption)
                .font(.body)
                .foregroundColor(.primary)
            
            // Actions (Like, Comment, Share)
            Divider()
            HStack {
                Button { print("Like \(post.user)") } label: {
                    Label("12", systemImage: "heart")
                }
                
                Button { print("Comment on \(post.user)") } label: {
                    Label("4", systemImage: "bubble.right")
                }
                
                Spacer()
                
                Button { print("Share \(post.user)") } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2) // Liquid Glass Shadow
    }
}

