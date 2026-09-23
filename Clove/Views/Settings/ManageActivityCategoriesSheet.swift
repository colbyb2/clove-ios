import SwiftUI

struct ManageActivityCategoriesSheet: View {
    let onChange: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var categories: [ActivityCategoryDefinition] = []
    @State private var editingCategory: ActivityCategoryDefinition?
    @State private var showingNewCategory = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(categories) { category in
                        Button {
                            guard !category.isPreset else { return }
                            editingCategory = category
                        } label: {
                            HStack(spacing: CloveSpacing.medium) {
                                Image(systemName: category.symbol)
                                    .foregroundStyle(category.color)
                                    .frame(width: 30, height: 30)
                                    .background(category.color.opacity(0.14), in: Circle())
                                Text(category.name)
                                    .foregroundStyle(CloveColors.primaryText)
                                Spacer()
                                Text(category.isPreset ? "Built in" : "Edit")
                                    .font(.caption)
                                    .foregroundStyle(CloveColors.secondaryText)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("Renaming a custom category updates its label everywhere without changing past entries.")
                }
            }
            .navigationTitle("Activity Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewCategory = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add activity category")
                }
            }
            .onAppear(perform: reload)
            .sheet(isPresented: $showingNewCategory) {
                ActivityCategoryEditor(category: nil) {
                    reload()
                    onChange()
                }
            }
            .sheet(item: $editingCategory) { category in
                ActivityCategoryEditor(category: category) {
                    reload()
                    onChange()
                }
            }
        }
    }

    private func reload() {
        categories = ActivityCategoryRepo.shared.getAll()
    }
}

private struct ActivityCategoryEditor: View {
    let category: ActivityCategoryDefinition?
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var symbol = ActivityCategoryStyle.symbols[0]
    @State private var colorHex = ActivityCategoryStyle.colors[0]
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Category name", text: $name)
                }

                Section("Symbol") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6)) {
                        ForEach(ActivityCategoryStyle.symbols, id: \.self) { option in
                            Button {
                                symbol = option
                            } label: {
                                Image(systemName: option)
                                    .frame(width: 36, height: 36)
                                    .foregroundStyle(symbol == option ? .white : Color(hex: colorHex))
                                    .background(symbol == option ? Color(hex: colorHex) : Color.clear, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option)
                            .accessibilityAddTraits(symbol == option ? .isSelected : [])
                        }
                    }
                }

                Section("Color") {
                    HStack {
                        ForEach(ActivityCategoryStyle.colors, id: \.self) { option in
                            Button {
                                colorHex = option
                            } label: {
                                Circle()
                                    .fill(Color(hex: option))
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if colorHex == option {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Color option")
                            .accessibilityAddTraits(colorHex == option ? .isSelected : [])
                        }
                    }
                }

                if category != nil {
                    Section {
                        Button("Delete Category", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    } footer: {
                        Text("Activities in this category will move to Other.")
                    }
                }
            }
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                guard let category else { return }
                name = category.name
                symbol = category.symbol
                colorHex = category.colorHex
            }
            .confirmationDialog("Delete this category?", isPresented: $showingDeleteConfirmation) {
                Button("Delete Category", role: .destructive) { deleteCategory() }
            }
        }
    }

    private func save() {
        let repo = ActivityCategoryRepo.shared
        let saved: Bool
        if var category {
            category.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            category.symbol = symbol
            category.colorHex = colorHex
            saved = repo.save(category)
        } else {
            saved = repo.create(name: name, symbol: symbol, colorHex: colorHex) != nil
        }
        guard saved else { return }
        onSave()
        dismiss()
    }

    private func deleteCategory() {
        guard let category, ActivityCategoryRepo.shared.delete(category) else { return }
        onSave()
        dismiss()
    }
}
