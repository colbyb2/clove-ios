import SwiftUI

struct CustomMetricTracker: View {
    let viewModel: TodayViewModel
    let definition: CustomMetricDefinition
    @State private var editing = false

    var body: some View {
        TodayActionRow(
            title: definition.name,
            icon: definition.icon,
            summary: viewModel.customValues[definition.id].map(definition.format) ?? "Not logged",
            hasValue: viewModel.customValues[definition.id] != nil,
            tint: Color(hex: definition.colorHex)
        ) {
            editing = true
        }
        .sheet(isPresented: $editing) {
            CustomMetricValueEditor(definition: definition, date: viewModel.selectedDate, existing: viewModel.customValues[definition.id]) {
                viewModel.setCustomValue($0, for: definition.id)
            }
        }
    }
}

struct CustomMetricValueEditor: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.USE_SLIDER_INPUT) private var usesSliders = true
    let definition: CustomMetricDefinition
    let date: Date
    let existing: CustomDailyValue?
    let onDone: (CustomDailyValue?) throws -> Void
    @State private var number = ""
    @State private var boolean: Bool?
    @State private var hours = ""
    @State private var minutes = ""
    @State private var rating: Double?
    @State private var errorMessage: String?
    @FocusState private var numberFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(date.formatted(date: .complete, time: .omitted), systemImage: "calendar")
                        .font(.subheadline).foregroundStyle(CloveColors.secondaryText)
                }
                Section(definition.configurationLabel) {
                    switch definition.kind {
                    case .number, .count:
                        HStack {
                            TextField("Not logged", text: $number).keyboardType(definition.kind == .count ? .numberPad : .decimalPad)
                                .focused($numberFocused).font(.title2).accessibilityLabel(definition.name)
                            if !definition.unit.isEmpty { Text(definition.unit).foregroundStyle(CloveColors.secondaryText) }
                        }
                        if definition.kind == .number {
                            Button("Change sign", systemImage: "plus.forwardslash.minus") {
                                number = number.hasPrefix("-") ? String(number.dropFirst()) : "-" + number
                            }
                        }
                        if definition.kind == .count {
                            HStack {
                                Button("Decrease", systemImage: "minus.circle") { adjustCount(-1) }.buttonStyle(.borderless)
                                Spacer()
                                Button("Increase", systemImage: "plus.circle") { adjustCount(1) }.buttonStyle(.borderless)
                            }
                        }
                        Text("Enter the total for this day. Updating it replaces the previous value.")
                            .font(.caption).foregroundStyle(CloveColors.secondaryText)
                    case .yesNo:
                        HStack {
                            answerButton("No", selected: boolean == false) { boolean = false }
                            answerButton("Yes", selected: boolean == true) { boolean = true }
                        }
                    case .rating:
                        Text(rating.map { "\(Int($0)) / \(definition.ratingMax)" } ?? "Not logged").font(.title2)
                        if usesSliders {
                            Slider(value: Binding(get: { rating ?? Double(definition.ratingMin) }, set: { rating = $0 }),
                                   in: Double(definition.ratingMin)...Double(definition.ratingMax), step: 1)
                                .accessibilityLabel(definition.name)
                            if rating == nil { Button("Record \(definition.ratingMin)") { rating = Double(definition.ratingMin) } }
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))]) {
                                ForEach(definition.ratingMin...definition.ratingMax, id: \.self) { value in
                                    answerButton("\(value)", selected: rating == Double(value)) { rating = Double(value) }
                                }
                            }
                        }
                        HStack { Text("\(definition.ratingMin)"); Spacer(); Text("\(definition.ratingMax)") }
                            .font(.caption).foregroundStyle(CloveColors.secondaryText)
                    case .duration:
                        HStack(spacing: 20) {
                            VStack(alignment: .leading) {
                                Text("Hours").font(.caption).foregroundStyle(CloveColors.secondaryText)
                                TextField("0", text: $hours).keyboardType(.numberPad).font(.title2).accessibilityLabel("Hours")
                            }
                            VStack(alignment: .leading) {
                                Text("Minutes").font(.caption).foregroundStyle(CloveColors.secondaryText)
                                TextField("0", text: $minutes).keyboardType(.numberPad).font(.title2).accessibilityLabel("Minutes")
                            }
                        }
                        if hours.isEmpty && minutes.isEmpty { Button("Record 0h 0m") { hours = "0"; minutes = "0" } }
                    }
                }
                if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
                if existing != nil {
                    Section { Button("Clear entry", role: .destructive) {
                        do { try onDone(nil); dismiss() } catch { errorMessage = error.localizedDescription }
                    } }
                }
            }
            .navigationTitle(definition.name).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done", action: finish) }
            }
            .tint(Color(hex: definition.colorHex))
            .onAppear {
                number = existing?.numberValue.map { $0.formatted(.number.grouping(.never).precision(.fractionLength(0...definition.precision))) } ?? ""
                numberFocused = definition.kind == .number || definition.kind == .count
                boolean = existing?.booleanValue
                rating = existing?.numberValue
                hours = existing?.durationMinutes.map { String($0 / 60) } ?? ""
                minutes = existing?.durationMinutes.map { String($0 % 60) } ?? ""
            }
        }
    }
    private func answerButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 42)
                .background(selected ? Color(hex: definition.colorHex).opacity(0.2) : CloveColors.background, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color(hex: definition.colorHex) : .clear))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func adjustCount(_ change: Int) {
        let current = Double(number) ?? 0
        number = max(0, current + Double(change)).formatted(.number.grouping(.never).precision(.fractionLength(0)))
    }
    private func finish() {
        var value = CustomDailyValue(metricID: definition.id, dayKey: LocalDayKey.make(for: date))
        switch definition.kind {
        case .number, .count:
            value.numberValue = CustomMetricInput.number(number)
        case .yesNo: value.booleanValue = boolean
        case .rating: value.numberValue = rating
        case .duration:
            guard !hours.isEmpty || !minutes.isEmpty,
                  let h = Int(hours.isEmpty ? "0" : hours), let m = Int(minutes.isEmpty ? "0" : minutes),
                  (0...8760).contains(h), (0...59).contains(m) else {
                errorMessage = "Enter hours and minutes (0–59), or explicitly record zero."
                return
            }
            value.durationMinutes = h * 60 + m
        }
        do { try value.validate(for: definition); try onDone(value); dismiss() }
        catch { errorMessage = error.localizedDescription }
    }
}
