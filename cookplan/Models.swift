
//
//  Models.swift
//  CookPlanRoar
//
//  Core data models and enums used across the app.
//

import Foundation

// MARK: - App Settings

public enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark
    public var id: String { rawValue }
}

public enum Language: String, Codable, CaseIterable, Identifiable {
    case en
    case es
    case fr
    public var id: String { rawValue }
}

// MARK: - Recipes

public typealias RecipeID = UUID

public struct Ingredient: Codable, Hashable, Identifiable {
    public enum Unit: String, Codable, CaseIterable {
        case piece, g, kg, ml, l, tbsp, tsp, cup
    }

    public var id: UUID = UUID()
    public var name: String
    public var quantity: Double?
    public var unit: Unit?
    public var aisle: Aisle

    public init(id: UUID = UUID(), name: String, quantity: Double? = nil, unit: Unit? = nil, aisle: Aisle = .other) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.aisle = aisle
    }
}

public enum Tag: String, Codable, CaseIterable, Identifiable {
    case road
    case flight
    case hotel
    case noFridge = "no-fridge"
    case kids
    case fiveMin = "5-min"
    case vegetarian
    case highProtein = "high-protein"
    case snack
    public var id: String { rawValue }
}

public struct Recipe: Codable, Identifiable, Hashable {
    public var id: RecipeID = UUID()
    public var title: String
    public var tags: [Tag]
    public var timeMinutes: Int? // prep time
    public var ingredients: [Ingredient]
    public var steps: [String]
    public var isFavorite: Bool

    public init(
        id: RecipeID = UUID(),
        title: String,
        tags: [Tag] = [],
        timeMinutes: Int? = nil,
        ingredients: [Ingredient] = [],
        steps: [String] = [],
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.tags = tags
        self.timeMinutes = timeMinutes
        self.ingredients = ingredients
        self.steps = steps
        self.isFavorite = isFavorite
    }
}

// MARK: - Planner / Trips

public enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack
    public var id: String { rawValue }
}

public struct MealSlot: Codable, Hashable, Identifiable {
    public var id: UUID = UUID()
    public var type: MealType
    public var recipeIDs: [RecipeID]

    public init(id: UUID = UUID(), type: MealType, recipeIDs: [RecipeID] = []) {
        self.id = id
        self.type = type
        self.recipeIDs = recipeIDs
    }
}

public struct MealPlanDay: Codable, Hashable, Identifiable {
    public var id: UUID = UUID()
    public var date: Date
    public var meals: [MealSlot]

    public init(id: UUID = UUID(), date: Date, meals: [MealSlot] = []) {
        self.id = id
        self.date = date
        self.meals = meals
    }
}

public struct Trip: Codable, Identifiable, Hashable {
    public var id: UUID = UUID()
    public var name: String
    public var startDate: Date
    public var endDate: Date
    public var notes: String?
    public var days: [MealPlanDay]

    public init(
        id: UUID = UUID(),
        name: String,
        startDate: Date,
        endDate: Date,
        notes: String? = nil,
        days: [MealPlanDay] = []
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.days = days
    }
}

// MARK: - Groceries

public enum Aisle: String, Codable, CaseIterable, Identifiable {
    case produce
    case bakery
    case dairy
    case canned
    case dryGoods
    case condiments
    case snacks
    case beverages
    case deli
    case other
    public var id: String { rawValue }
}

public struct GroceryItem: Codable, Identifiable, Hashable {
    public var id: UUID = UUID()
    public var name: String
    public var aisle: Aisle
    public var quantity: Double?
    public var unit: Ingredient.Unit?
    public var isChecked: Bool
    public var recipeRef: RecipeID? // optional back-reference

    public init(
        id: UUID = UUID(),
        name: String,
        aisle: Aisle = .other,
        quantity: Double? = nil,
        unit: Ingredient.Unit? = nil,
        isChecked: Bool = false,
        recipeRef: RecipeID? = nil
    ) {
        self.id = id
        self.name = name
        self.aisle = aisle
        self.quantity = quantity
        self.unit = unit
        self.isChecked = isChecked
        self.recipeRef = recipeRef
    }
}

// MARK: - Favorites (Quick Packs)

public struct QuickPack: Codable, Identifiable, Hashable {
    public var id: UUID = UUID()
    public var title: String
    public var recipeIDs: [RecipeID]

    public init(id: UUID = UUID(), title: String, recipeIDs: [RecipeID]) {
        self.id = id
        self.title = title
        self.recipeIDs = recipeIDs
    }
}

// MARK: - Root Persisted State

public struct PersistedStore: Codable {
    public var recipes: [Recipe]
    public var favorites: Set<RecipeID>
    public var quickPacks: [QuickPack]
    public var trips: [Trip]
    public var groceries: [GroceryItem]
    public var settings: Settings

    public init(
        recipes: [Recipe] = [],
        favorites: Set<RecipeID> = [],
        quickPacks: [QuickPack] = [],
        trips: [Trip] = [],
        groceries: [GroceryItem] = [],
        settings: Settings = .init()
    ) {
        self.recipes = recipes
        self.favorites = favorites
        self.quickPacks = quickPacks
        self.trips = trips
        self.groceries = groceries
        self.settings = settings
    }
}

public struct Settings: Codable {
    public var theme: ThemeMode
    public var language: Language
    public var privacyURLString: String?

    public init(theme: ThemeMode = .system, language: Language = .en, privacyURLString: String? = nil) {
        self.theme = theme
        self.language = language
        self.privacyURLString = privacyURLString
    }
}
