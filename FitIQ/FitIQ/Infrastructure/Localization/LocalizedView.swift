//
//  LocalizedView.swift
//
//  Wrapper view that forces content to re-render when language changes
//

import SwiftUI

/// Wrapper view that observes LocaleManager and forces its content to update when language changes
struct LocalizedView<Content: View>: View {
    @EnvironmentObject private var localeManager: LocaleManager
    
    private let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        content()
            .id(localeManager.currentLanguageCode) // Force re-render when language changes
    }
}
