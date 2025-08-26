




//
//  MainTabView.swift
//  CookPlanRoar
//
//  Tab bar with five sections: Recipes, Planner, Groceries, Favorites, Settings
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: Tab = .recipes
    
    enum Tab: Hashable {
        case recipes
        case planner
        case groceries
        case favorites
        case settings
    }
    
    var body: some View {
        TabView(selection: $selection) {
            RecipesScreen()
                .tabItem {
                    Label { Text(LocalizedStringKey("tab_recipes")) } icon: { Image(systemName: "fork.knife") }
                }
                .tag(Tab.recipes)
            
            PlannerScreen()
                .tabItem {
                    Label { Text(LocalizedStringKey("tab_planner")) } icon: { Image(systemName: "calendar") }
                }
                .tag(Tab.planner)
            
            GroceriesScreen()
                .tabItem {
                    Label { Text(LocalizedStringKey("tab_groceries")) } icon: { Image(systemName: "cart") }
                }
                .tag(Tab.groceries)
            
            FavoritesScreen()
                .tabItem {
                    Label { Text(LocalizedStringKey("tab_favorites")) } icon: { Image(systemName: "star") }
                }
                .tag(Tab.favorites)
            
            SettingsScreen()
                .tabItem {
                    Label { Text(LocalizedStringKey("tab_settings")) } icon: { Image(systemName: "gearshape") }
                }
                .tag(Tab.settings)
        }
    }
}

// NOTE: The five screen views (RecipesScreen, PlannerScreen, GroceriesScreen, FavoritesScreen, SettingsScreen)
// will be provided in their own files next. They will read/write AppState and include seed content directly on-screen.
