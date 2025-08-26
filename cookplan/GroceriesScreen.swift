//
//  GroceriesScreen.swift
//  CookPlanRoar
//
//  Grouped grocery list with checkboxes, clear-checked, and manual add.
//

import SwiftUI

struct GroceriesScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingAdd = false
    private struct Confirmation: Identifiable { let id = UUID(); let key: String }
    @State private var confirmation: Confirmation? = nil
    
    var body: some View {
        NavigationStack {
            Group {
                if appState.store.groceries.isEmpty {
                    EmptyGroceriesView()
                } else {
                    List {
                        ForEach(nonEmptyAisles, id: \.self) { aisle in
                            Section(header: Text(aisleTitle(aisle))) {
                                ForEach(items(in: aisle), id: \.id) { item in
                                    GroceryRow(item: binding(for: item))
                                }
                                .onDelete { indexSet in
                                    delete(at: indexSet, in: aisle)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(Text(LocalizedStringKey("tab_groceries")))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) { clearChecked() } label: {
                        Label(LocalizedStringKey("clear_checked"), systemImage: "checkmark.circle.badge.xmark")
                    }
                    .disabled(appState.store.groceries.allSatisfy { !$0.isChecked })
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Label(LocalizedStringKey("add_item"), systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddGrocerySheet { newItem in
                    appState.store.groceries.append(newItem)
                    confirmation = Confirmation(key: "added_to_groceries")
                }
                .presentationDetents([.medium])
            }
            .alert(item: $confirmation) { conf in
                Alert(title: Text(LocalizedStringKey(conf.key)), dismissButton: .default(Text(LocalizedStringKey("ok"))))
            }
        }
    }
    
    // MARK: - Helpers
    private var nonEmptyAisles: [Aisle] {
        Aisle.allCases.filter { aisle in
            appState.store.groceries.contains { $0.aisle == aisle }
        }
    }
    
    private func items(in aisle: Aisle) -> [GroceryItem] {
        appState.store.groceries.filter { $0.aisle == aisle }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private func binding(for item: GroceryItem) -> Binding<GroceryItem> {
        guard let idx = appState.store.groceries.firstIndex(of: item) else {
            return .constant(item)
        }
        return $appState.store.groceries[idx]
    }
    
    private func delete(at offsets: IndexSet, in aisle: Aisle) {
        let ids = items(in: aisle).map { $0.id }
        let toRemove = offsets.compactMap { idx in ids[safe: idx] }
        appState.store.groceries.removeAll { gi in toRemove.contains(gi.id) }
    }
    
    private func clearChecked() {
        appState.store.groceries.removeAll { $0.isChecked }
    }
    
    private func aisleTitle(_ a: Aisle) -> String {
        switch a {
        case .produce: return "Produce"
        case .bakery: return "Bakery"
        case .dairy: return "Dairy"
        case .canned: return "Canned"
        case .dryGoods: return "Dry Goods"
        case .condiments: return "Condiments"
        case .snacks: return "Snacks"
        case .beverages: return "Beverages"
        case .deli: return "Deli"
        case .other: return NSLocalizedString("aisle", comment: "")
        }
    }
}

// MARK: - Row
private struct GroceryRow: View {
    @Binding var item: GroceryItem
    
    var body: some View {
        HStack(spacing: 12) {
            Button { item.isChecked.toggle() } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                if let q = item.quantity, let u = item.unit {
                    Text("\(Int(q)) \(u.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { item.isChecked.toggle() }
    }
}

// MARK: - Empty State
private struct EmptyGroceriesView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "cart").font(.largeTitle)
            Text(LocalizedStringKey("empty_groceries")).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Add Sheet
private struct AddGrocerySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var quantity: String = ""
    @State private var unit: Ingredient.Unit = .piece
    @State private var aisle: Aisle = .other
    @State private var lastValidQuantity: String = ""
    private struct LocalAlert: Identifiable { let id = UUID(); let key: String }
    @State private var alert: LocalAlert? = nil
    let onAdd: (GroceryItem) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(LocalizedStringKey("add_item"))) {
                    TextField("Name", text: $name)
                    HStack {
                        TextField("Qty", text: $quantity)
                            .keyboardType(.numberPad)
                            .onChange(of: quantity) { newValue in
                                if !newValue.isEmpty && newValue.contains(where: { !$0.isNumber }) {
                                    alert = LocalAlert(key: "digits_only")
                                    quantity = lastValidQuantity
                                } else {
                                    lastValidQuantity = newValue
                                }
                            }
                        Picker("Unit", selection: $unit) {
                            ForEach(Ingredient.Unit.allCases, id: \.self) { u in
                                Text(u.rawValue).tag(u)
                            }
                        }
                    }
                    Picker(LocalizedStringKey("aisle"), selection: $aisle) {
                        ForEach(Aisle.allCases, id: \.self) { a in
                            Text(aisleLabel(a)).tag(a)
                        }
                    }
                }
            }
            .navigationTitle(Text(LocalizedStringKey("add_item")))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .alert(item: $alert) { a in
            Alert(title: Text(LocalizedStringKey(a.key)), dismissButton: .default(Text(LocalizedStringKey("ok"))))
        }
    }
    
    private func aisleLabel(_ a: Aisle) -> String {
        switch a {
        case .produce: return "Produce"
        case .bakery: return "Bakery"
        case .dairy: return "Dairy"
        case .canned: return "Canned"
        case .dryGoods: return "Dry Goods"
        case .condiments: return "Condiments"
        case .snacks: return "Snacks"
        case .beverages: return "Beverages"
        case .deli: return "Deli"
        case .other: return NSLocalizedString("aisle", comment: "")
        }
    }
    
    private func add() {
        let q = Double(quantity)
        let item = GroceryItem(name: name, aisle: aisle, quantity: q, unit: q == nil ? nil : unit)
        onAdd(item)
        dismiss()
    }
}

// MARK: - Safe index helper
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
