//
//  RecipesScreen.swift
//  CookPlanRoar
//
//  Search + filter recipes, view details, add to favorites. Seed content comes from AppState.
//

import SwiftUI

struct RecipesScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var search: String = ""
    @State private var noFridgeOnly: Bool = false
    @State private var selectedTags: Set<Tag> = []
    @State private var selectedRecipe: Recipe? = nil
    @State private var showingAddRecipe = false
    private struct Confirmation: Identifiable { let id = UUID(); let key: String }
    @State private var confirmation: Confirmation? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search + Filters
                FiltersBar(search: $search,
                           noFridgeOnly: $noFridgeOnly,
                           selectedTags: $selectedTags)
                    .padding(.horizontal)
                    .padding(.top)
                
                if filteredRecipes.isEmpty {
                    EmptyStateView(textKey: "empty_recipes", systemImage: "text.magnifyingglass")
                        .padding()
                } else {
                    List {
                        ForEach(filteredRecipes, id: \.id) { recipe in
                            RecipeRow(recipe: recipe,
                                      isFavorite: appState.store.favorites.contains(recipe.id)) {
                                toggleFavorite(recipe)
                                if appState.store.favorites.contains(recipe.id) { confirmation = Confirmation(key: "added_to_favorites") }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { selectedRecipe = recipe }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(Text(LocalizedStringKey("tab_recipes")))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddRecipe = true } label: { Image(systemName: "plus") }
                }
            }
        }
        .sheet(item: $selectedRecipe) { recipe in
            RecipeDetailView(recipe: binding(for: recipe),
                             isFavorite: appState.store.favorites.contains(recipe.id),
                             onToggleFavorite: {
                                 toggleFavorite(recipe)
                                 if appState.store.favorites.contains(recipe.id) { confirmation = Confirmation(key: "added_to_favorites") }
                             },
                             onAddToPlan: {
                                 addToPlan(recipe)
                                 confirmation = Confirmation(key: "added_to_plan")
                             })
        }
        .sheet(isPresented: $showingAddRecipe) {
            AddRecipeSheet { newRecipe in
                appState.store.recipes.append(newRecipe)
            }
            .presentationDetents([.large])
        }
        .alert(item: $confirmation) { conf in
            Alert(title: Text(LocalizedStringKey(conf.key)), dismissButton: .default(Text(LocalizedStringKey("ok"))))
        }
    }
    
    // MARK: - Derived
    private var filteredRecipes: [Recipe] {
        var items = appState.store.recipes
        if noFridgeOnly {
            items = items.filter { $0.tags.contains(.noFridge) }
        }
        if !selectedTags.isEmpty {
            items = items.filter { !$0.tags.isEmpty && !Set($0.tags).isDisjoint(with: selectedTags) }
        }
        if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let q = search.lowercased()
            items = items.filter { r in
                r.title.lowercased().contains(q) || r.ingredients.contains { $0.name.lowercased().contains(q) }
            }
        }
        return items
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
        if appState.store.favorites.contains(recipe.id) {
            confirmation = Confirmation(key: "added_to_favorites")
        }
    }
    
    private func addToPlan(_ recipe: Recipe) {
        // Minimal UX: add to today’s lunch in the first trip if exists, else create a 1-day trip.
        if appState.store.trips.isEmpty {
            let today = Date()
            let day = MealPlanDay(date: today, meals: [
                MealSlot(type: .breakfast, recipeIDs: []),
                MealSlot(type: .lunch, recipeIDs: [recipe.id]),
                MealSlot(type: .dinner, recipeIDs: []),
                MealSlot(type: .snack, recipeIDs: [])
            ])
            let trip = Trip(name: appState.t("weekend_trip"), startDate: today, endDate: today, days: [day])
            appState.store.trips.append(trip)
        } else {
            // Add to first trip, first day, lunch (or create slot if missing)
            guard var firstTrip = appState.store.trips.first else { return }
            if firstTrip.days.isEmpty {
                firstTrip.days = [MealPlanDay(date: Date(), meals: [])]
            }
            var firstDay = firstTrip.days[0]
            if let idx = firstDay.meals.firstIndex(where: { $0.type == .lunch }) {
                firstDay.meals[idx].recipeIDs.append(recipe.id)
            } else {
                firstDay.meals.append(MealSlot(type: .lunch, recipeIDs: [recipe.id]))
            }
            firstTrip.days[0] = firstDay
            appState.store.trips[0] = firstTrip
        }
    }
    
    private func binding(for recipe: Recipe) -> Binding<Recipe> {
        guard let idx = appState.store.recipes.firstIndex(of: recipe) else {
            return .constant(recipe)
        }
        return $appState.store.recipes[idx]
    }
}

// MARK: - Row
private struct RecipeRow: View {
    let recipe: Recipe
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "takeoutbag.and.cup.and.straw")
                .font(.title2)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(recipe.title)
                        .font(.headline)
                    Spacer()
                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                    }
                    .buttonStyle(.plain)
                }
                TagChips(tags: recipe.tags)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Filters Bar
private struct FiltersBar: View {
    @Binding var search: String
    @Binding var noFridgeOnly: Bool
    @Binding var selectedTags: Set<Tag>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField(LocalizedStringKey("search_placeholder"), text: $search)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            .padding(10)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            HStack {
                Toggle(LocalizedStringKey("filter_no_fridge"), isOn: $noFridgeOnly)
                Spacer()
                Menu {
                    ForEach(Tag.allCases, id: \.self) { tag in
                        let isOn = selectedTags.contains(tag)
                        Button(action: {
                            if isOn { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
                        }) {
                            Label(tagTitle(tag), systemImage: isOn ? "checkmark.circle.fill" : "circle")
                        }
                    }
                    if !selectedTags.isEmpty {
                        Divider()
                        Button(LocalizedStringKey("clear")) { selectedTags.removeAll() }
                    }
                } label: {
                    Label(LocalizedStringKey("tags"), systemImage: "tag")
                }
            }
        }
    }
    
    private func tagTitle(_ tag: Tag) -> String {
        switch tag {
        case .road: return "road"
        case .flight: return "flight"
        case .hotel: return "hotel"
        case .noFridge: return "no-fridge"
        case .kids: return "kids"
        case .fiveMin: return "5-min"
        case .vegetarian: return "vegetarian"
        case .highProtein: return "high-protein"
        case .snack: return "snack"
        }
    }
}

// MARK: - Tag Chips
private struct TagChips: View {
    let tags: [Tag]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(title(tag))
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
    private func title(_ tag: Tag) -> String {
        switch tag {
        case .road: return "road"
        case .flight: return "flight"
        case .hotel: return "hotel"
        case .noFridge: return "no-fridge"
        case .kids: return "kids"
        case .fiveMin: return "5-min"
        case .vegetarian: return "vegetarian"
        case .highProtein: return "high-protein"
        case .snack: return "snack"
        }
    }
}

// MARK: - Recipe Detail
private struct RecipeDetailView: View {
    @Binding var recipe: Recipe
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onAddToPlan: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(recipe.title)
                            .font(.title2).bold()
                        Spacer()
                        Button(action: onToggleFavorite) {
                            Label("", systemImage: isFavorite ? "star.fill" : "star")
                        }
                        .labelStyle(.iconOnly)
                    }
                    TagChips(tags: recipe.tags)
                    
                    if let t = recipe.timeMinutes {
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                            Text(String(format: NSLocalizedString("approx_minutes", comment: "~%%d min"), t))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Group {
                        Text(LocalizedStringKey("ingredients")).font(.headline)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(recipe.ingredients, id: \.id) { ing in
                                HStack(alignment: .firstTextBaseline) {
                                    Image(systemName: "checkmark.circle")
                                    Text(ingredientLine(ing))
                                }
                            }
                        }
                    }
                    
                    Group {
                        Text(LocalizedStringKey("steps")).font(.headline)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { (i, step) in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(i+1).").bold()
                                    Text(step)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button(action: onAddToPlan) {
                            Label(LocalizedStringKey("add_to_plan"), systemImage: "calendar.badge.plus")
                        }
                        Spacer()
                        Button(action: onToggleFavorite) {
                            Label(LocalizedStringKey("add_to_favorites"), systemImage: isFavorite ? "star.fill" : "star")
                        }
                    }
                }
            }
        }
    }
    
    private func ingredientLine(_ ing: Ingredient) -> String {
        var parts: [String] = [ing.name]
        if let q = ing.quantity { parts.append(String(format: "%.0f", q)) }
        if let u = ing.unit { parts.append(u.rawValue) }
        return parts.joined(separator: " ")
    }
}

// MARK: - Empty State
private struct EmptyStateView: View {
    let textKey: String
    let systemImage: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage).font(.largeTitle)
            Text(LocalizedStringKey(textKey)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Add Recipe Sheet
private struct AddRecipeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var time: String = ""
    @State private var lastValidTime: String = ""
    private struct LocalAlert: Identifiable { let id = UUID(); let key: String }
    @State private var alert: LocalAlert? = nil
    @State private var selected: Set<Tag> = []
    @State private var ingredientsLine: String = "" // comma-separated names
    @State private var stepsText: String = "" // one step per line
    let onSave: (Recipe) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(LocalizedStringKey("name"))) {
                    TextField(LocalizedStringKey("name"), text: $title)
                }
                Section(header: Text(LocalizedStringKey("time_min"))) {
                    TextField(LocalizedStringKey("example_10"), text: $time)
                        .keyboardType(.numberPad)
                        .onChange(of: time) { newValue in
                            if !newValue.isEmpty && newValue.contains(where: { !$0.isNumber }) {
                                alert = LocalAlert(key: "digits_only")
                                time = lastValidTime
                            } else {
                                lastValidTime = newValue
                            }
                        }
                }
                Section(header: Text(LocalizedStringKey("tags"))) {
                    TagMultiPicker(selected: $selected)
                }
                Section(header: Text(LocalizedStringKey("ingredients_csv"))) {
                    TextField("Oats, Milk, Honey", text: $ingredientsLine)
                }
                Section(header: Text(LocalizedStringKey("steps_one_per_line"))) {
                    TextEditor(text: $stepsText).frame(minHeight: 120)
                }
            }
            .navigationTitle(Text(LocalizedStringKey("add_recipe")))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(LocalizedStringKey("close")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(LocalizedStringKey("save")) { save() }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
            .alert(item: $alert) { a in
                Alert(title: Text(LocalizedStringKey(a.key)), dismissButton: .default(Text(LocalizedStringKey("ok"))))
            }
        }
    }
    
    private func save() {
        let timeVal = Int(time)
        let names = ingredientsLine.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let ings: [Ingredient] = names.map { Ingredient(name: $0, quantity: nil, unit: nil, aisle: .other) }
        let steps: [String] = stepsText.split(whereSeparator: { $0.isNewline }).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let recipe = Recipe(title: title, tags: Array(selected), timeMinutes: timeVal, ingredients: ings, steps: steps)
        onSave(recipe)
        dismiss()
    }
}

private struct TagMultiPicker: View {
    @Binding var selected: Set<Tag>
    var body: some View {
        ForEach(Tag.allCases, id: \.self) { tag in
            let isOn = selected.contains(tag)
            Button {
                if isOn { selected.remove(tag) } else { selected.insert(tag) }
            } label: {
                HStack {
                    Text(label(for: tag))
                    Spacer()
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                }
            }
        }
    }
    private func label(for tag: Tag) -> String {
        switch tag {
        case .road: return "road"
        case .flight: return "flight"
        case .hotel: return "hotel"
        case .noFridge: return "no-fridge"
        case .kids: return "kids"
        case .fiveMin: return "5-min"
        case .vegetarian: return "vegetarian"
        case .highProtein: return "high-protein"
        case .snack: return "snack"
        }
    }
}
