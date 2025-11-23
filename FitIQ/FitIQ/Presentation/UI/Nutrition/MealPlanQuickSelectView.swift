//
//  MealPlanQuickSelectView.swift
//  FitIQ
//
//  Created by Marcos Barbero on 18/10/2025.
//

import Foundation
import SwiftUI

//struct MealPlanQuickSelectView: View {
//    @Environment(\.dismiss) var dismiss
//    @State private var viewModel: MealQuickSelectViewModel
//    
//    // Action callback to notify parent views to refresh.
//    let onSave: () -> Void
//    
//    private let primaryColor = Color.ascendBlue
//
//    init(viewModel: MealQuickSelectViewModel, onSave: @escaping () -> Void) {
//        self._viewModel = State(initialValue: viewModel)
//        self.onSave = onSave
//    }
//
//    var body: some View {
//        NavigationStack {
//            List {
//                Section(header: Text("Quick Templates & Recent Meals")) {
//                    ForEach(viewModel.templates) { template in
//                        HStack {
//                            VStack(alignment: .leading) {
//                                Text(template.name).fontWeight(.medium)
//                                Text("+\(template.calories) kcal").font(.caption).foregroundColor(.secondary)
//                            }
//                            Spacer()
//                            Button("Add") {
//                                // Mock saving the template and closing
//                                print("Logged template: \(template.name)")
//                                onSave() // Trigger parent refresh
//                                dismiss()
//                            }
//                            .buttonStyle(.borderedProminent)
//                            .tint(primaryColor)
//                        }
//                    }
//                }
//            }
//            .navigationTitle("Quick Log")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Done") { dismiss() }
//                }
//            }
//        }
//    }
//}
