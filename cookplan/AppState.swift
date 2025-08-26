//
//  AppState.swift
//  CookPlanRoar
//
//  Central observable object for state, persistence, localization, and seed data
//

import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    // Published state
    @Published var store: PersistedStore
    @Published var uiLocale: Locale
    
    private let saveURL: URL
    private var cancellables = Set<AnyCancellable>()
    
    // Localization dictionary (minimal)
    private let localized: [Language: [String: String]] = [
        .en: [
            "weekend_trip": "Weekend Road Trip",
            "light_pack": "Light 1-Day",
            "family_pack": "Family Road 2-Meals"
        ],
        .es: [
            "weekend_trip": "Viaje de fin de semana",
            "light_pack": "Pack ligero 1 día",
            "family_pack": "Pack familiar 2 comidas"
        ],
        .fr: [
            "weekend_trip": "Voyage de week-end",
            "light_pack": "Pack léger 1 jour",
            "family_pack": "Pack familial 2 repas"
        ]
    ]
    
    init() {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.saveURL = dir.appendingPathComponent("CookPlanRoarStore.json")
        
        if let data = try? Data(contentsOf: saveURL),
           let decoded = try? JSONDecoder().decode(PersistedStore.self, from: data) {
            self.store = decoded
            self.uiLocale = Locale(identifier: decoded.settings.language.rawValue)
        } else {
            let seed = AppState.seedData()
            self.store = seed
            self.uiLocale = Locale(identifier: seed.settings.language.rawValue)
        }
        
        // Autosave on any store change
        $store
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] newStore in
                self?.save(store: newStore)
            }
            .store(in: &cancellables)
        
        $store
            .map { $0.settings.language.rawValue }
            .removeDuplicates()
            .sink { [weak self] lang in
                self?.uiLocale = Locale(identifier: lang)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Persistence
    private func save(store: PersistedStore) {
        if let data = try? JSONEncoder().encode(store) {
            try? data.write(to: saveURL)
        }
    }
    
    // MARK: - Localization
    func t(_ key: String) -> String {
        let lang = store.settings.language
        return localized[lang]?[key] ?? localized[.en]?[key] ?? key
    }
    
    // MARK: - Seed Content
    private static func seedData() -> PersistedStore {
        // Ingredients quick helpers
        func ing(_ name: String, _ qty: Double? = nil, _ unit: Ingredient.Unit? = nil, aisle: Aisle = .other) -> Ingredient {
            Ingredient(name: name, quantity: qty, unit: unit, aisle: aisle)
        }
        
        // Recipes
        let oats = Recipe(
            title: "Overnight Oats To-Go",
            tags: [.noFridge, .fiveMin, .hotel],
            timeMinutes: 5,
            ingredients: [
                ing("Oats", 60, .g, aisle: .dryGoods),
                ing("Milk", 200, .ml, aisle: .dairy),
                ing("Chia seeds", 1, .tbsp, aisle: .dryGoods),
                ing("Honey", 1, .tbsp, aisle: .condiments)
            ],
            steps: ["Mix ingredients", "Leave overnight in fridge", "Grab & go"]
        )
        
        let wraps = Recipe(
            title: "Tortilla Wraps Kit",
            tags: [.road, .kids, .fiveMin],
            ingredients: [
                ing("Tortillas", 4, .piece, aisle: .bakery),
                ing("Cheese", 100, .g, aisle: .dairy),
                ing("Turkey slices", 150, .g, aisle: .deli),
                ing("Lettuce", nil, nil, aisle: .produce),
                ing("Sauce pack", nil, nil, aisle: .condiments)
            ],
            steps: ["Assemble ingredients", "Wrap", "Pack"]
        )
        
        let couscous = Recipe(
            title: "Couscous Jar Salad",
            tags: [.hotel, .noFridge, .vegetarian],
            ingredients: [
                ing("Couscous", 80, .g, aisle: .dryGoods),
                ing("Boiling water", 120, .ml, aisle: .other),
                ing("Chickpeas", 150, .g, aisle: .canned),
                ing("Tomato", 1, .piece, aisle: .produce),
                ing("Cucumber", 1, .piece, aisle: .produce),
                ing("Olive oil", 1, .tbsp, aisle: .condiments)
            ],
            steps: ["Hydrate couscous", "Chop vegetables", "Mix all"]
        )
        
        let trailMix = Recipe(
            title: "Protein Trail Mix",
            tags: [.flight, .snack, .highProtein, .noFridge],
            ingredients: [
                ing("Almonds", 50, .g, aisle: .snacks),
                ing("Peanuts", 50, .g, aisle: .snacks),
                ing("Raisins", 40, .g, aisle: .snacks),
                ing("Dark chocolate", 30, .g, aisle: .snacks)
            ],
            steps: ["Portion into bags", "Pack"]
        )
        
        let tunaBox = Recipe(
            title: "Tuna & Bean Travel Box",
            tags: [.road, .highProtein],
            ingredients: [
                ing("Canned tuna", 1, .piece, aisle: .canned),
                ing("Canned beans", 1, .piece, aisle: .canned),
                ing("Olive oil", 1, .tbsp, aisle: .condiments),
                ing("Lemon", 1, .piece, aisle: .produce),
                ing("Salt/Pepper", nil, nil, aisle: .condiments)
            ],
            steps: ["Drain cans", "Mix with oil & lemon", "Pack"]
        )
        
        let hummus = Recipe(
            title: "Hummus & Veggie Sticks Kit",
            tags: [.vegetarian, .noFridge, .snack],
            ingredients: [
                ing("Hummus cups", 2, .piece, aisle: .canned),
                ing("Carrots", 2, .piece, aisle: .produce),
                ing("Cucumber", 1, .piece, aisle: .produce),
                ing("Pita bread", 1, .piece, aisle: .bakery)
            ],
            steps: ["Cut vegetables", "Portion hummus", "Pack"]
        )
        
        let recipes = [oats, wraps, couscous, trailMix, tunaBox, hummus]
        
        // Favorites
        let favoriteIDs: Set<RecipeID> = [oats.id, couscous.id]
        
        // Quick Packs
        let quickPacks: [QuickPack] = [
            QuickPack(title: "Light 1-Day", recipeIDs: [oats.id, couscous.id, trailMix.id]),
            QuickPack(title: "Family Road 2-Meals", recipeIDs: [wraps.id, hummus.id])
        ]
        
        // Example Trip
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let trip = Trip(
            name: "Weekend Road Trip",
            startDate: today,
            endDate: tomorrow,
            days: [
                MealPlanDay(date: today, meals: [
                    MealSlot(type: .breakfast, recipeIDs: [oats.id]),
                    MealSlot(type: .lunch, recipeIDs: [wraps.id]),
                    MealSlot(type: .snack, recipeIDs: [trailMix.id]),
                    MealSlot(type: .dinner, recipeIDs: [tunaBox.id])
                ]),
                MealPlanDay(date: tomorrow, meals: [
                    MealSlot(type: .breakfast, recipeIDs: [oats.id]),
                    MealSlot(type: .lunch, recipeIDs: [couscous.id]),
                    MealSlot(type: .snack, recipeIDs: [hummus.id]),
                    MealSlot(type: .dinner, recipeIDs: [wraps.id])
                ])
            ]
        )
        
        // Groceries (example auto list)
        let groceries: [GroceryItem] = [
            ing("Lettuce", nil, nil, aisle: .produce).asGrocery(),
            ing("Tomato", 1, .piece, aisle: .produce).asGrocery(),
            ing("Cucumber", 2, .piece, aisle: .produce).asGrocery(),
            ing("Carrots", 2, .piece, aisle: .produce).asGrocery(),
            ing("Lemon", 1, .piece, aisle: .produce).asGrocery(),
            ing("Tortillas", 4, .piece, aisle: .bakery).asGrocery(),
            ing("Pita bread", 1, .piece, aisle: .bakery).asGrocery(),
            ing("Milk", 200, .ml, aisle: .dairy).asGrocery(),
            ing("Cheese", 100, .g, aisle: .dairy).asGrocery(),
            ing("Canned tuna", 1, .piece, aisle: .canned).asGrocery(),
            ing("Canned beans", 1, .piece, aisle: .canned).asGrocery(),
            ing("Hummus cups", 2, .piece, aisle: .canned).asGrocery(),
            ing("Oats", 60, .g, aisle: .dryGoods).asGrocery(),
            ing("Chia seeds", 1, .tbsp, aisle: .dryGoods).asGrocery(),
            ing("Couscous", 80, .g, aisle: .dryGoods).asGrocery(),
            ing("Raisins", 40, .g, aisle: .snacks).asGrocery(),
            ing("Almonds", 50, .g, aisle: .snacks).asGrocery(),
            ing("Peanuts", 50, .g, aisle: .snacks).asGrocery(),
            ing("Dark chocolate", 30, .g, aisle: .snacks).asGrocery(),
            ing("Olive oil", 1, .tbsp, aisle: .condiments).asGrocery(),
            ing("Honey", 1, .tbsp, aisle: .condiments).asGrocery(),
            ing("Sauce pack", nil, nil, aisle: .condiments).asGrocery(),
            ing("Salt/Pepper", nil, nil, aisle: .condiments).asGrocery()
        ]
        
        return PersistedStore(
            recipes: recipes,
            favorites: favoriteIDs,
            quickPacks: quickPacks,
            trips: [trip],
            groceries: groceries,
            settings: Settings(theme: .system, language: .en)
        )
    }
}

// MARK: - Helpers

fileprivate extension Ingredient {
    func asGrocery() -> GroceryItem {
        GroceryItem(name: self.name, aisle: self.aisle, quantity: self.quantity, unit: self.unit)
    }
}
