//
//  FavoritesScreen.swift
//  CookPlanRoar
//
//  Shows favorite recipes and Quick Packs; allows adding to plan or groceries.
//

import SwiftUI

struct FavoritesScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedRecipe: Recipe? = nil
    private struct Confirmation: Identifiable { let id = UUID(); let key: String }
    @State private var confirmation: Confirmation? = nil
    
    private var favoriteRecipes: [Recipe] {
        appState.store.recipes.filter { appState.store.favorites.contains($0.id) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if favoriteRecipes.isEmpty && appState.store.quickPacks.isEmpty {
                    EmptyFavsView()
                } else {
                    List {
                        if !favoriteRecipes.isEmpty {
                            Section(header: Text(LocalizedStringKey("tab_favorites"))) {
                                ForEach(favoriteRecipes, id: \.id) { r in
                                    FavoriteRow(recipe: r,
                                                isFavorite: appState.store.favorites.contains(r.id),
                                                onToggleFavorite: { toggleFavorite(r) })
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedRecipe = r }
                                }
                            }
                        }
                        if !appState.store.quickPacks.isEmpty {
                            Section(header: Text(LocalizedStringKey("quick_packs"))) {
                                ForEach(appState.store.quickPacks, id: \.id) { pack in
                                    QuickPackRow(title: pack.title,
                                                 count: pack.recipeIDs.count,
                                                 onAddToPlan: { addPackToPlan(pack) },
                                                 onGroceries: { addPackToGroceries(pack) })
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(Text(LocalizedStringKey("tab_favorites")))
        }
        .sheet(item: $selectedRecipe) { recipe in
            FavRecipeDetailView(recipe: binding(for: recipe),
                                isFavorite: appState.store.favorites.contains(recipe.id),
                                onToggleFavorite: { toggleFavorite(recipe) },
                                onAddToPlan: {
                                    addSingleToPlan(recipe)
                                    confirmation = Confirmation(key: "added_to_plan")
                                })
        }
        .alert(item: $confirmation) { conf in
            Alert(title: Text(LocalizedStringKey(conf.key)), dismissButton: .default(Text(LocalizedStringKey("ok"))))
        }
    }
    
    // MARK: - Actions
    private func toggleFavorite(_ recipe: Recipe) {
        if appState.store.favorites.contains(recipe.id) {
            appState.store.favorites.remove(recipe.id)
        } else {
            appState.store.favorites.insert(recipe.id)
        }
        if let idx = appState.store.recipes.firstIndex(where: { $0.id == recipe.id }) {
            appState.store.recipes[idx].isFavorite = appState.store.favorites.contains(recipe.id)
        }
    }
    
    private func addSingleToPlan(_ recipe: Recipe) {
        if appState.store.trips.isEmpty {
            let today = Date()
            let day = MealPlanDay(date: today, meals: [
                MealSlot(type: .breakfast),
                MealSlot(type: .lunch, recipeIDs: [recipe.id]),
                MealSlot(type: .dinner),
                MealSlot(type: .snack)
            ])
            let trip = Trip(name: appState.t("weekend_trip"), startDate: today, endDate: today, days: [day])
            appState.store.trips.append(trip)
        } else {
            var t = appState.store.trips[0]
            if t.days.isEmpty { t.days = [MealPlanDay(date: Date(), meals: [])] }
            var d = t.days[0]
            if let i = d.meals.firstIndex(where: { $0.type == .lunch }) {
                d.meals[i].recipeIDs.append(recipe.id)
            } else {
                d.meals.append(MealSlot(type: .lunch, recipeIDs: [recipe.id]))
            }
            t.days[0] = d
            appState.store.trips[0] = t
        }
    }
    
    private func addPackToPlan(_ pack: QuickPack) {
        // Add all recipes to today’s day across meals in order (b,l,d,s repeating)
        let order: [MealType] = [.breakfast, .lunch, .dinner, .snack]
        var trip: Trip
        if appState.store.trips.isEmpty {
            let today = Date()
            trip = Trip(name: appState.t("weekend_trip"), startDate: today, endDate: today, days: [MealPlanDay(date: today, meals: [])])
            appState.store.trips.append(trip)
        }
        trip = appState.store.trips[0]
        if trip.days.isEmpty { trip.days = [MealPlanDay(date: Date(), meals: [])] }
        var day = trip.days[0]
        for (idx, rid) in pack.recipeIDs.enumerated() {
            let meal = order[idx % order.count]
            if let i = day.meals.firstIndex(where: { $0.type == meal }) {
                day.meals[i].recipeIDs.append(rid)
            } else {
                day.meals.append(MealSlot(type: meal, recipeIDs: [rid]))
            }
        }
        trip.days[0] = day
        appState.store.trips[0] = trip
        confirmation = Confirmation(key: "added_to_plan")
    }
    
    private func addPackToGroceries(_ pack: QuickPack) {
        let recipeByID = Dictionary(uniqueKeysWithValues: appState.store.recipes.map { ($0.id, $0) })
        var merged = Dictionary(uniqueKeysWithValues: appState.store.groceries.map { ($0.name.lowercased(), $0) })
        for rid in pack.recipeIDs {
            guard let r = recipeByID[rid] else { continue }
            for ing in r.ingredients {
                let key = ing.name.lowercased()
                if var ex = merged[key] {
                    if let q1 = ex.quantity, let q2 = ing.quantity, ex.unit == ing.unit { ex.quantity = q1 + q2 }
                    merged[key] = ex
                } else {
                    merged[key] = GroceryItem(name: ing.name, aisle: ing.aisle, quantity: ing.quantity, unit: ing.unit)
                }
            }
        }
        appState.store.groceries = Array(merged.values).sorted { $0.name < $1.name }
        confirmation = Confirmation(key: "added_to_groceries")
    }
    
    private func binding(for recipe: Recipe) -> Binding<Recipe> {
        guard let idx = appState.store.recipes.firstIndex(of: recipe) else { return .constant(recipe) }
        return $appState.store.recipes[idx]
    }
}

// MARK: - Rows & Empty
private struct FavoriteRow: View {
    let recipe: Recipe
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill").foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(recipe.title).font(.headline)
                    Spacer()
                    Button(action: onToggleFavorite) { Image(systemName: isFavorite ? "star.slash" : "star") }
                        .buttonStyle(.plain)
                }
                LocalTagChips(tags: recipe.tags)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct QuickPackRow: View {
    let title: String
    let count: Int
    let onAddToPlan: () -> Void
    let onGroceries: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Text("\(count)")
                    Text(LocalizedStringKey("recipes_word"))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Button(action: onGroceries) {
                    Label(LocalizedStringKey("tab_groceries"), systemImage: "cart")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct EmptyFavsView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "star").font(.largeTitle)
            Text(LocalizedStringKey("empty_favorites")).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Minimal tag chips (local version)
private struct LocalTagChips: View {
    let tags: [Tag]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(LocalizedStringKey(tagKey(tag)))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func tagKey(_ tag: Tag) -> String {
        switch tag {
        case .road: return "tag_road"
        case .flight: return "tag_flight"
        case .hotel: return "tag_hotel"
        case .noFridge: return "tag_no_fridge"
        case .kids: return "tag_kids"
        case .fiveMin: return "tag_5_min"
        case .vegetarian: return "tag_vegetarian"
        case .highProtein: return "tag_high_protein"
        case .snack: return "tag_snack"
        }
    }
}

// Simple detail reused locally
private struct FavRecipeDetailView: View {
    @Binding var recipe: Recipe
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onAddToPlan: () -> Void
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(recipe.title).font(.title2).bold()
                        Spacer()
                        Button(action: onToggleFavorite) { Image(systemName: isFavorite ? "star.fill" : "star") }
                            .buttonStyle(.plain)
                    }
                    LocalTagChips(tags: recipe.tags)
                    Group {
                        Text(LocalizedStringKey("ingredients")).font(.headline)
                        ForEach(recipe.ingredients, id: \.id) { ing in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                Text(ingredientLine(ing))
                            }
                        }
                    }
                    Group {
                        Text(LocalizedStringKey("steps")).font(.headline)
                        ForEach(Array(recipe.steps.enumerated()), id: \.offset) { i, s in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(i+1).").bold()
                                Text(s)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    private func ingredientLine(_ ing: Ingredient) -> String {
        var parts: [String] = [ing.name]
        if let q = ing.quantity { parts.append(String(format: "%.0f", q)) }
        if let u = ing.unit { parts.append(u.rawValue) }
        return parts.joined(separator: " ")
    }
}
