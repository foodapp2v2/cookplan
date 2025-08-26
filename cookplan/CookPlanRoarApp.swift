



//
//  CookPlanRoarApp.swift
//  CookPlanRoar
//
//  Entry point of the app, applies theme and injects AppState
//

import SwiftUI

@main
struct CookPlanRoarApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                  .environment(\.locale, appState.uiLocale)
                  .id("lang-\(appState.uiLocale.identifier)")
                  .preferredColorScheme(colorScheme(for: appState.store.settings.theme))
        }
    }
    
    private func colorScheme(for theme: ThemeMode) -> ColorScheme? {
        switch theme {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
