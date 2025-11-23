//
//  MealSuggestionsTileView.swift
//  HealthRestart
//
//  Created by Marcos Barbero on 26/09/2025.
//

import Foundation
import SwiftUI

struct MealSuggestionsCardView: View {
    @State var vm: MealSuggestionsViewModel

    @State private var showingEditor = false
    @State private var selectedSuggestion: MealSuggestion?

    var body: some View {
        // Only show the tile if we have suggestions or are loading
        if !vm.suggestions.isEmpty || vm.isLoading {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Suggested meals")
                        .font(.headline)
                    Spacer()
                    Button(action: { Task { await vm.refresh() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }

                if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(vm.suggestions) { s in
                        Button(action: {
                            selectedSuggestion = s
                            showingEditor = true
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(s.title).font(.subheadline).bold()
                                    Text(s.description).font(.caption).foregroundColor(.secondary).lineLimit(2)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("\(s.estimatedCalories) kcal").font(.caption2)
                                    Text(s.tags.first ?? "").font(.caption2).foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                        }
                    }
                }
            }
            .padding()
            .onAppear { Task { await vm.refresh() } }
            .sheet(isPresented: $showingEditor) {
                if let sel = selectedSuggestion {
                    MealSuggestionEditorView(suggestion: sel, vm: vm)
                }
            }
        }
    }
}
