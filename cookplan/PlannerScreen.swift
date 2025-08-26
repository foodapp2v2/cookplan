//
//  PlannerScreen.swift
//  CookPlanRoar
//
//  Trips list, day/meal planning, and groceries generation from planned recipes.
//

import SwiftUI

struct PlannerScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingNewTrip = false
    private struct Confirmation: Identifiable { let id = UUID(); let key: String }
    @State private var confirmation: Confirmation? = nil
    
    var body: some View {
        NavigationStack {
            Group {
                if appState.store.trips.isEmpty {
                    PlannerEmptyState()
                } else {
                    List {
                        ForEach(appState.store.trips.indices, id: \.self) { i in
                            NavigationLink(value: i) {
                                TripRow(trip: appState.store.trips[i])
                            }
                        }
                        .onDelete(perform: deleteTrips)
                    }
                    .navigationDestination(for: Int.self) { index in
                        TripDetailView(tripIndex: index)
                    }
                }
            }
            .navigationTitle(Text(LocalizedStringKey("tab_planner")))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewTrip = true
                    } label: {
                        Label(LocalizedStringKey("create_trip"), systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewTrip) {
                NewTripSheet { newTrip in
                    appState.store.trips.append(newTrip)
                }
                .presentationDetents([.medium, .large])
            }
            .alert(item: $confirmation) { conf in
                Alert(title: Text(LocalizedStringKey(conf.key)), dismissButton: .default(Text(LocalizedStringKey("ok"))))
            }
        }
    }
    
    private func deleteTrips(at offsets: IndexSet) {
        appState.store.trips.remove(atOffsets: offsets)
    }
}

// MARK: - Row & Empty
private struct TripRow: View {
    let trip: Trip
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(trip.name).font(.headline)
            Text("\(trip.startDate, style: .date) – \(trip.endDate, style: .date)")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct PlannerEmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus").font(.largeTitle)
            Text(LocalizedStringKey("empty_planner"))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - New Trip Sheet
private struct NewTripSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    let onCreate: (Trip) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(LocalizedStringKey("trip_name"))) {
                    TextField(LocalizedStringKey("trip_name"), text: $name)
                }
                Section {
                    DatePicker(LocalizedStringKey("start"), selection: $startDate, displayedComponents: .date)
                    DatePicker(LocalizedStringKey("end"), selection: $endDate, in: startDate..., displayedComponents: .date)
                }
            }
            .navigationTitle(Text(LocalizedStringKey("create_trip")))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("close")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("create")) { create() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func create() {
        // Build days array inclusive of start..end
        var days: [MealPlanDay] = []
        var date = startDate
        while date <= endDate {
            days.append(MealPlanDay(date: date, meals: MealType.allCases.map { MealSlot(type: $0) }))
            guard let next = Calendar.current.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        let trip = Trip(name: name, startDate: startDate, endDate: endDate, days: days)
        onCreate(trip)
        dismiss()
    }
}

// MARK: - Trip Detail
private struct TripDetailView: View {
    @EnvironmentObject private var appState: AppState
    let tripIndex: Int
    
    private struct AddTarget: Identifiable, Equatable {
        let dayIndex: Int
        let meal: MealType
        var id: String { "\(dayIndex)-\(meal.rawValue)" }
    }
    
    @State private var showingAddRecipeFor: AddTarget? = nil
    private struct LocalConfirmation: Identifiable { let id = UUID(); let key: String }
    @State private var localConfirmation: LocalConfirmation? = nil
    
    var body: some View {
        let binding = $appState.store.trips[tripIndex]
        List {
            ForEach(binding.days.indices, id: \.self) { dayIdx in
                Section(header: Text("\(binding.days[dayIdx].date.wrappedValue, style: .date)")) {
                    ForEach(MealType.allCases, id: \.self) { meal in
                        MealRow(tripBinding: binding, dayIndex: dayIdx, meal: meal) {
                            showingAddRecipeFor = AddTarget(dayIndex: dayIdx, meal: meal)
                        }
                    }
                }
            }
        }
        .navigationTitle(appState.store.trips[tripIndex].name)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    generateGroceries(from: appState.store.trips[tripIndex])
                    localConfirmation = LocalConfirmation(key: "added_to_groceries")
                } label: {
                    Label(LocalizedStringKey("generate_groceries"), systemImage: "cart.badge.plus")
                }
            }
        }
        .alert(item: $localConfirmation) { conf in
            Alert(title: Text(LocalizedStringKey(conf.key)), dismissButton: .default(Text(LocalizedStringKey("ok"))))
        }
        .sheet(item: $showingAddRecipeFor, content: { target in
            AddRecipeSheet(meal: target.meal) { recipe in
                add(recipe: recipe, toDay: target.dayIndex, meal: target.meal)
            }
            .presentationDetents([.medium, .large])
        })
    }
    
    private func add(recipe: Recipe, toDay dayIndex: Int, meal: MealType) {
        var trip = appState.store.trips[tripIndex]
        guard dayIndex < trip.days.count else { return }
        var day = trip.days[dayIndex]
        if let idx = day.meals.firstIndex(where: { $0.type == meal }) {
            day.meals[idx].recipeIDs.append(recipe.id)
        } else {
            day.meals.append(MealSlot(type: meal, recipeIDs: [recipe.id]))
        }
        trip.days[dayIndex] = day
        appState.store.trips[tripIndex] = trip
    }
    
    private func generateGroceries(from trip: Trip) {
        // Aggregate ingredients for all recipes in the trip and merge into store.groceries
        var aggregated: [String: GroceryItem] = [:]
        let recipeByID = Dictionary(uniqueKeysWithValues: appState.store.recipes.map { ($0.id, $0) })
        for day in trip.days {
            for slot in day.meals {
                for rid in slot.recipeIDs {
                    guard let r = recipeByID[rid] else { continue }
                    for ing in r.ingredients {
                        let key = ing.name.lowercased()
                        if var existing = aggregated[key] {
                            // Sum quantities only if units match and both quantities exist
                            if let q1 = existing.quantity, let q2 = ing.quantity, existing.unit == ing.unit {
                                existing.quantity = q1 + q2
                            }
                            aggregated[key] = existing
                        } else {
                            aggregated[key] = GroceryItem(name: ing.name, aisle: ing.aisle, quantity: ing.quantity, unit: ing.unit)
                        }
                    }
                }
            }
        }
        // Replace current groceries with generated list (simple strategy for MVP)
        appState.store.groceries = Array(aggregated.values).sorted { $0.name < $1.name }
    }
}

private struct MealRow: View {
    @Binding var tripBinding: Trip
    let dayIndex: Int
    let meal: MealType
    let onAdd: () -> Void
    
    var body: some View {
        let day = tripBinding.days[dayIndex]
        let items = day.meals.first(where: { $0.type == meal })?.recipeIDs ?? []
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(mealTitle(meal)).font(.headline)
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus.circle")
                }
            }
            if items.isEmpty {
                Text("—")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items, id: \.self) { rid in
                    HStack {
                        Text(recipeTitle(for: rid))
                        Spacer()
                        Button(role: .destructive) {
                            remove(rid)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func remove(_ rid: RecipeID) {
        guard let dayIdx = tripBinding.days.firstIndex(where: { $0.id == tripBinding.days[dayIndex].id }) else { return }
        var day = tripBinding.days[dayIdx]
        if let mi = day.meals.firstIndex(where: { $0.type == meal }) {
            day.meals[mi].recipeIDs.removeAll { $0 == rid }
            tripBinding.days[dayIdx] = day
        }
    }
    
    private func recipeTitle(for id: RecipeID) -> String {
        // Note: This view doesn't have access to AppState; show minimal placeholder.
        return "#" + id.uuidString.prefix(4) + "…"
    }
    
    private func mealTitle(_ m: MealType) -> String {
        switch m {
        case .breakfast: return NSLocalizedString("breakfast", comment: "")
        case .lunch: return NSLocalizedString("lunch", comment: "")
        case .dinner: return NSLocalizedString("dinner", comment: "")
        case .snack: return NSLocalizedString("snack", comment: "")
        }
    }
}

// MARK: - Add Recipe Sheet
private struct AddRecipeSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let meal: MealType
    @State private var query: String = ""
    let onPick: (Recipe) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered, id: \.id) { r in
                    Button {
                        onPick(r)
                        dismiss()
                    } label: {
                        HStack {
                            Text(r.title)
                            Spacer()
                            PlannerTagChips(tags: r.tags)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: Text(LocalizedStringKey("search_placeholder")))
            .navigationTitle(Text(LocalizedStringKey("add_to_plan")))
        }
    }
    
    private var filtered: [Recipe] {
        let base = appState.store.recipes
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return base }
        let q = query.lowercased()
        return base.filter { $0.title.lowercased().contains(q) || $0.ingredients.contains { $0.name.lowercased().contains(q) } }
    }
}

// MARK: - Local tag chips for Planner
private struct PlannerTagChips: View {
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
