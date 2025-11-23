//
//  MealSuggestionEditorView.swift
//  HealthRestart
//
//  Created by Marcos Barbero on 26/09/2025.
//

import Foundation
import SwiftUI

struct MealSuggestionEditorView: View {
    @Environment(\.dismiss) var dismiss
    let suggestion: MealSuggestion
    @ObservedObject var vm: MealSuggestionsViewModel
    @State private var editableItems: [SuggestedFoodItem]

    init(suggestion: MealSuggestion, vm: MealSuggestionsViewModel) {
        self.suggestion = suggestion
        self.vm = vm
        _editableItems = State(initialValue: suggestion.items)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(suggestion.title)) {
                    ForEach(Array(editableItems.enumerated()), id: \.1.name) { idx, item in
                        VStack(alignment: .leading) {
                            Text(item.name).font(.headline)
                            HStack {
                                TextField("Quantity (e.g. 120 g)", text: Binding(
                                    get: { editableItems[idx].quantityText },
                                    set: { editableItems[idx].quantityText = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                Spacer()
                                if let cal = item.calories {
                                    Text("\(cal) kcal").font(.caption)
                                }
                            }
                        }.padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Edit meal")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            // convert items -> a raw input string and call existing addMeal entrypoint
                            // Example: build "120g chicken breast; 150g broccoli"
                            let raw = editableItems.map { "\($0.quantityText) \($0.name)" }.joined(separator: ", ")
                            await vm.saveSuggestionAsMeal(suggestion: suggestion, rawInput: raw, items: editableItems)
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
