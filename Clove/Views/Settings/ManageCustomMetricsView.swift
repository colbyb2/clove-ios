import SwiftUI

struct ManageCustomMetricsView: View {
    @State private var model = CustomMetricsViewModel()
    @State private var editing: CustomMetricDefinition?
    var body: some View {
        List {
            Section {
                Text("Create daily measurements that work for you. Each metric stores one value per day; hidden and archived metrics keep their history.")
                    .font(.subheadline).foregroundStyle(CloveColors.secondaryText)
            }.listRowBackground(Color.clear)
            if let error = model.errorMessage {
                Section { Text(error).foregroundStyle(.red); Button("Retry", action: model.load) }
            }
            Section("Your metrics") {
                if model.definitions.filter({ $0.archivedAt == nil }).isEmpty {
                    Button { addMetric() } label: { Label("Create your first metric", systemImage: "plus.circle") }
                }
                ForEach(model.definitions.filter { $0.archivedAt == nil }) { definition in
                    HStack(spacing: 12) {
                        Button { editing = definition } label: {
                            HStack(spacing: 12) {
                                CustomMetricIcon(definition: definition)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(definition.name).font(.body.weight(.medium)).foregroundStyle(CloveColors.primaryText)
                                    Text(definition.configurationLabel).font(.caption).foregroundStyle(CloveColors.secondaryText)
                                }
                                Spacer(minLength: 0)
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Toggle("Show \(definition.name) on Today", isOn: Binding(get: { definition.isEnabled }, set: { enabled in
                            var copy = definition; copy.isEnabled = enabled; model.update(copy)
                        })).labelsHidden().tint(Theme.shared.accent)
                    }
                    .padding(.vertical, 4).listRowBackground(CloveColors.card)
                    .swipeActions {
                        Button("Archive", systemImage: "archivebox") {
                            var copy = definition; copy.archivedAt = Date(); copy.isEnabled = false; model.update(copy)
                        }.tint(.orange)
                    }
                }
                .onMove(perform: model.move)
            }
            let archived = model.definitions.filter { $0.archivedAt != nil }
            if !archived.isEmpty {
                Section("Archived") {
                    ForEach(archived) { definition in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(definition.name)
                                Text(definition.configurationLabel).font(.caption).foregroundStyle(CloveColors.secondaryText)
                            }
                            Spacer()
                            Button("Restore") {
                                var copy = definition; copy.archivedAt = nil; copy.isEnabled = true; model.update(copy)
                            }.buttonStyle(.borderless)
                        }.listRowBackground(CloveColors.card)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden).background(CloveColors.background)
        .navigationTitle("Custom Metrics").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Add metric", systemImage: "plus", action: addMetric) }
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
        .task { model.load() }
        .sheet(item: $editing) { definition in
            CustomMetricEditor(definition: definition, isNew: !model.definitions.contains { $0.id == definition.id }, hasHistory: { try model.hasHistory(definition) }, onSave: model.save)
        }
        .tint(Theme.shared.accent)
    }
    private func addMetric() {
        var definition = CustomMetricDefinition()
        definition.displayOrder = (model.definitions.map(\.displayOrder).max() ?? -1) + 1
        editing = definition
    }
}

struct CustomMetricIcon: View {
    let definition: CustomMetricDefinition
    var body: some View {
        Image(systemName: definition.icon).font(.headline).foregroundStyle(Color(hex: definition.colorHex))
            .frame(width: 40, height: 40)
            .background(Color(hex: definition.colorHex).opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
            .accessibilityHidden(true)
    }
}

private struct CustomMetricEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var definition: CustomMetricDefinition
    let isNew: Bool
    let hasHistory: () throws -> Bool
    let onSave: (CustomMetricDefinition) throws -> Void
    @State private var locked = false
    @State private var checkedHistory = false
    @State private var creatingCopy = false
    @State private var showingAppearance = false
    @State private var errorMessage: String?
    private enum Field: Hashable { case name, unit }
    @FocusState private var focusedField: Field?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let symbols = [
        ("number", "Number"), ("heart", "Heart"), ("bolt", "Energy"),
        ("brain.head.profile", "Mind"), ("leaf", "Leaf"), ("figure.walk", "Walking"),
        ("clock", "Clock"), ("drop", "Drop"), ("star", "Star"), ("checkmark.circle", "Checkmark")
    ]
    private let colors = [
        ("8b7cf8", "Purple"), ("3b82f6", "Blue"), ("14b8a6", "Teal"),
        ("f59e0b", "Amber"), ("ec4899", "Pink"), ("22c55e", "Green")
    ]
    private var accent: Color { Theme.shared.accent }
    private var trimmedName: String { definition.name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool {
        checkedHistory && !trimmedName.isEmpty && definition.name.count <= 60 && definition.unit.count <= 20
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    nameSection
                    inputSection
                    measurementSection
                    if locked { historyNotice }
                    previewSection
                    appearanceSection
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(CloveColors.background)
            .navigationTitle(isNew || creatingCopy ? "New Metric" : "Edit Metric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { saveBar }
            .task {
                do { locked = try hasHistory(); checkedHistory = true }
                catch { errorMessage = error.localizedDescription }
            }
            .tint(accent)
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Metric name")
            TextField("e.g. Sodium, Weight, or Screen time", text: $definition.name)
                .font(.body).textInputAutocapitalization(.sentences)
                .submitLabel(.done).focused($focusedField, equals: .name)
                .onSubmit { focusedField = nil }
                .padding(16)
                .background(CloveColors.card, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel("Metric name")
            if definition.name.count > 60 {
                Text("Use 60 characters or fewer.").font(.caption).foregroundStyle(CloveColors.error)
            }
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("What will you record?")
                Spacer()
                if locked { Image(systemName: "lock.fill").foregroundStyle(CloveColors.secondaryText).accessibilityLabel("Input type is fixed") }
            }
            if locked {
                HStack(spacing: 12) {
                    Image(systemName: definition.kind.icon).foregroundStyle(accent)
                    Text(definition.kind.title).font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(16)
                .background(CloveColors.card, in: RoundedRectangle(cornerRadius: 14))
            } else {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) {
                        ForEach(CustomMetricKind.allCases) { typeChoice($0) }
                    }
                } else {
                    Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                        GridRow { typeChoice(.number); typeChoice(.count) }
                        GridRow { typeChoice(.yesNo); typeChoice(.rating) }
                        GridRow { typeChoice(.duration).gridCellColumns(2) }
                    }
                }
            }
            Text(typeHint).font(.caption).foregroundStyle(CloveColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func typeChoice(_ kind: CustomMetricKind) -> some View {
        let selected = definition.kind == kind
        return Button {
            selectType(kind)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: kind.icon).font(.system(size: 17, weight: .medium)).frame(width: 22)
                Text(kind.title).font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                if selected { Image(systemName: "checkmark.circle.fill").font(.system(size: 15)) }
            }
            .foregroundStyle(selected ? accent : CloveColors.primaryText)
            .padding(.horizontal, 12).padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .background(selected ? accent.opacity(0.12) : CloveColors.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14).strokeBorder(selected ? accent.opacity(0.65) : .clear, lineWidth: 1.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(!checkedHistory)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(kind.detail)
    }

    private var typeHint: String {
        switch definition.kind {
        case .number: "Measurements such as weight or sodium, with an optional unit."
        case .count: "Whole-number totals, such as steps or repetitions."
        case .yesNo: "Record Yes or No. Unanswered days stay unrecorded."
        case .rating: "Choose a scale that works for you, such as 1–5 or 0–10."
        case .duration: "Record a daily total in hours and minutes."
        }
    }

    @ViewBuilder
    private var measurementSection: some View {
        if definition.kind == .number || definition.kind == .count {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionTitle("Unit")
                    Text("Optional").font(.caption).foregroundStyle(CloveColors.secondaryText)
                }
                HStack {
                    TextField("e.g. mg, lb, or steps", text: $definition.unit)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($focusedField, equals: .unit).submitLabel(.done)
                        .onSubmit { focusedField = nil }
                        .accessibilityLabel("Unit, optional")
                }
                .padding(16)
                .background(CloveColors.card, in: RoundedRectangle(cornerRadius: 14))
                if definition.unit.count > 20 {
                    Text("Use 20 characters or fewer.").font(.caption).foregroundStyle(CloveColors.error)
                }
                if definition.kind == .number {
                    sectionTitle("Decimal places").padding(.top, 6)
                    Picker("Decimal places", selection: $definition.precision) {
                        Text("Whole").tag(0)
                        Text("0.0").tag(1)
                        Text("0.00").tag(2)
                        Text("0.000").tag(3)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .disabled(locked || !checkedHistory)
        } else if definition.kind == .rating {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Rating scale")
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { scalePresets }
                    VStack(alignment: .leading, spacing: 8) { scalePresets }
                }
                VStack(spacing: 12) {
                    Stepper(value: $definition.ratingMin, in: 0...(definition.ratingMax - 1)) {
                        HStack {
                            Text("Minimum").foregroundStyle(CloveColors.secondaryText)
                            Spacer()
                            Text("\(definition.ratingMin)").fontWeight(.semibold).monospacedDigit()
                        }
                    }
                    Divider()
                    Stepper(value: $definition.ratingMax, in: (definition.ratingMin + 1)...100) {
                        HStack {
                            Text("Maximum").foregroundStyle(CloveColors.secondaryText)
                            Spacer()
                            Text("\(definition.ratingMax)").fontWeight(.semibold).monospacedDigit()
                        }
                    }
                }
                .font(.subheadline).padding(16)
                .background(CloveColors.card, in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(locked || !checkedHistory)
        }
    }

    private var scalePresets: some View {
        ForEach([0...10, 1...5, 1...10], id: \.self) { range in
            let selected = definition.ratingMin == range.lowerBound && definition.ratingMax == range.upperBound
            Button {
                definition.ratingMin = range.lowerBound
                definition.ratingMax = range.upperBound
            } label: {
                Text("\(range.lowerBound)–\(range.upperBound)")
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                    .padding(.horizontal, 18).frame(minHeight: 44)
                    .foregroundStyle(selected ? accent : CloveColors.secondaryText)
                    .background(selected ? accent.opacity(0.12) : CloveColors.card, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Scale from \(range.lowerBound) to \(range.upperBound)")
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }

    private var historyNotice: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your recorded values stay consistent", systemImage: "lock.shield")
                .font(.subheadline.weight(.semibold))
            Text("Type, unit, and scale are fixed after your first entry. You can still change the name, icon, and color.")
                .font(.caption).foregroundStyle(CloveColors.secondaryText)
            Button("Create a new metric instead") {
                definition.id = UUID().uuidString.lowercased()
                definition.createdAt = Date()
                definition.name += " (new)"
                definition.hasRecordedValues = false
                definition.archivedAt = nil
                definition.isEnabled = true
                creatingCopy = true
                locked = false
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("On your Today screen")
            TodayActionRow(
                title: trimmedName.isEmpty ? "Your metric" : trimmedName,
                icon: definition.icon,
                summary: "Not logged",
                hasValue: false,
                tint: Color(hex: definition.colorHex)
            ) {}
            .disabled(true)
        }
    }

    private var appearanceSection: some View {
        DisclosureGroup(isExpanded: $showingAppearance) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Icon").font(.caption.weight(.semibold)).foregroundStyle(CloveColors.secondaryText)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                    ForEach(symbols, id: \.0) { symbol, label in
                        Button { definition.icon = symbol } label: {
                            Image(systemName: symbol).font(.system(size: 19, weight: .medium))
                                .foregroundStyle(definition.icon == symbol ? Color(hex: definition.colorHex) : CloveColors.secondaryText)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(definition.icon == symbol ? Color(hex: definition.colorHex).opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain).accessibilityLabel(label)
                        .accessibilityAddTraits(definition.icon == symbol ? .isSelected : [])
                    }
                }
                Divider()
                Text("Color").font(.caption.weight(.semibold)).foregroundStyle(CloveColors.secondaryText)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                    ForEach(colors, id: \.0) { hex, label in
                        Button { definition.colorHex = hex } label: {
                            Circle().fill(Color(hex: hex)).frame(width: 28, height: 28)
                                .overlay {
                                    if definition.colorHex == hex {
                                        Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                    }
                                }
                                .padding(5)
                                .overlay { Circle().strokeBorder(definition.colorHex == hex ? Color(hex: hex) : .clear, lineWidth: 2) }
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.plain).accessibilityLabel(label)
                        .accessibilityAddTraits(definition.colorHex == hex ? .isSelected : [])
                    }
                }
            }
            .padding(.top, 16)
        } label: {
            HStack(spacing: 12) {
                CustomMetricIcon(definition: definition)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Icon & color").font(.subheadline.weight(.semibold)).foregroundStyle(CloveColors.primaryText)
                    Text("Make this metric easy to recognize").font(.caption).foregroundStyle(CloveColors.secondaryText)
                }
            }
        }
        .padding(16)
        .background(CloveColors.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var saveBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.caption).foregroundStyle(CloveColors.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: save) {
                Text(isNew || creatingCopy ? "Create Metric" : "Save Changes")
                    .font(.body.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .foregroundStyle(canSave ? Color.white : CloveColors.secondaryText)
                    .background(canSave ? accent : CloveColors.card, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain).disabled(!canSave)
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)
        .background(.bar)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(CloveColors.primaryText)
    }

    private func selectType(_ kind: CustomMetricKind) {
        guard definition.kind != kind else { return }
        definition.kind = kind
        definition.icon = kind.icon
        if kind != .number { definition.precision = 0 }
        if kind != .number && kind != .count { definition.unit = "" }
        if kind != .rating { definition.ratingMin = 0; definition.ratingMax = 10 }
    }

    private func save() {
        focusedField = nil
        do { try onSave(definition); dismiss() }
        catch { errorMessage = error.localizedDescription }
    }
}
