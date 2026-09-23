//
//  QuickAddSymptomShet.swift
//  Clove
//
//  Created by Colby Brown on 12/3/25.
//

import SwiftUI
import CryptoKit

struct QuickAddSymptomSheet: View {
    private enum TrackingScope: String, CaseIterable, Identifiable {
        case todayOnly = "Just this day"
        case everyDay = "Every day"
        var id: String { rawValue }
    }

    @Environment(TodayViewModel.self) var viewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var symptomName: String = ""
    @State private var isBinary: Bool = false
    @State private var trackingScope: TrackingScope = .todayOnly
    @State private var rating: Double = 5
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    introHeader
                    trackingScopeSection
                    symptomDetailsSection
                    valueSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(CloveColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Log a Symptom")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(CloveColors.secondaryText)
                }
            }
            .safeAreaInset(edge: .bottom) {
                saveButton
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var introHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "bandage.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.shared.accent)
                .frame(width: 44, height: 44)
                .background(Theme.shared.accent.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("What are you noticing?")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(CloveColors.primaryText)
                Text("Add it just for this date, or keep it in your daily check-in.")
                    .font(.subheadline)
                    .foregroundStyle(CloveColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var trackingScopeSection: some View {
        sheetSection(title: "Where should it appear?", step: "1") {
            HStack(spacing: 10) {
                optionCard(
                    title: "This day",
                    detail: viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted),
                    icon: "calendar",
                    isSelected: trackingScope == .todayOnly
                ) {
                    trackingScope = .todayOnly
                }
                optionCard(
                    title: "Daily tracker",
                    detail: "From now on",
                    icon: "calendar.badge.plus",
                    isSelected: trackingScope == .everyDay
                ) {
                    trackingScope = .everyDay
                }
            }
        }
    }

    private var symptomDetailsSection: some View {
        sheetSection(title: "Describe the symptom", step: "2") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Name")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CloveColors.secondaryText)

                    TextField("Headache, nausea, dizziness…", text: $symptomName)
                        .font(.system(.body, design: .rounded))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 50)
                        .background(CloveColors.background, in: RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isTextFieldFocused ? Theme.shared.accent : CloveColors.secondaryText.opacity(0.14),
                                    lineWidth: isTextFieldFocused ? 1.5 : 1
                                )
                        }
                        .focused($isTextFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if isAddButtonEnabled { saveSymptom() }
                        }
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("How should it be measured?")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CloveColors.secondaryText)

                    HStack(spacing: 10) {
                        optionCard(
                            title: "Severity",
                            detail: "0–10 scale",
                            icon: "slider.horizontal.3",
                            isSelected: !isBinary
                        ) { isBinary = false }
                        optionCard(
                            title: "Present",
                            detail: "Yes or no",
                            icon: "checkmark.circle",
                            isSelected: isBinary
                        ) { isBinary = true }
                    }
                }
            }
        }
        .onChange(of: isBinary) { _, binary in
            rating = binary ? 10 : 5
        }
    }

    private var valueSection: some View {
        sheetSection(title: "Log today’s value", step: "3") {
            if isBinary {
                HStack(spacing: 10) {
                    valueButton(title: "No", icon: "xmark.circle", value: 0)
                    valueButton(title: "Yes", icon: "checkmark.circle", value: 10)
                }
            } else {
                VStack(spacing: 8) {
                    HStack {
                        Text("Severity")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(Int(rating))")
                            .font(.title3.bold())
                            .foregroundStyle(Theme.shared.accent)
                    }
                    Slider(value: $rating, in: 0...10, step: 1)
                        .tint(Theme.shared.accent)
                    HStack {
                        Text("0 · none")
                        Spacer()
                        Text("10 · most severe")
                    }
                    .font(.caption2)
                    .foregroundStyle(CloveColors.secondaryText)
                }
            }
        }
    }

    private var saveButton: some View {
        Button(action: saveSymptom) {
            Label(
                trackingScope == .todayOnly ? "Log for This Day" : "Add to Daily Tracker",
                systemImage: "checkmark.circle.fill"
            )
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                isAddButtonEnabled ? Theme.shared.accent : CloveColors.secondaryText.opacity(0.35),
                in: RoundedRectangle(cornerRadius: CloveCorners.medium)
            )
        }
        .disabled(!isAddButtonEnabled)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .animation(.easeInOut(duration: 0.18), value: isAddButtonEnabled)
    }

    private func sheetSection<Content: View>(
        title: String,
        step: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(step)
                    .font(.caption.bold())
                    .foregroundStyle(Theme.shared.accent)
                    .frame(width: 24, height: 24)
                    .background(Theme.shared.accent.opacity(0.12), in: Circle())
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(CloveColors.primaryText)
            }
            content()
        }
        .padding(16)
        .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
    }

    private func optionCard(
        title: String,
        detail: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { action() }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(isSelected ? Theme.shared.accent : CloveColors.secondaryText)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Theme.shared.accent : CloveColors.secondaryText.opacity(0.5))
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CloveColors.primaryText)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                isSelected ? Theme.shared.accent.opacity(0.1) : CloveColors.background,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Theme.shared.accent.opacity(0.5) : Color.clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func valueButton(title: String, icon: String, value newValue: Double) -> some View {
        let isSelected = rating == newValue
        return Button {
            rating = newValue
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Label(title, systemImage: isSelected ? "\(icon).fill" : icon)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.shared.accent : CloveColors.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(
                    isSelected ? Theme.shared.accent.opacity(0.12) : CloveColors.background,
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Theme.shared.accent.opacity(0.45) : Color.clear, lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var isAddButtonEnabled: Bool {
        !symptomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveSymptom() {
        let trimmedName = symptomName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if trackingScope == .todayOnly {
            appendRating(id: hashSymptomName(trimmedName), name: trimmedName)
            ToastManager.shared.showToast(
                message: "\(trimmedName) logged for \(viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted)) only",
                color: CloveColors.success,
                icon: Image(systemName: "calendar.badge.checkmark")
            )
        } else if let existing = SymptomsRepo.shared.getTrackedSymptoms().first(where: {
            $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
        }), let id = existing.id {
            appendRating(id: id, name: existing.name)
            ToastManager.shared.showToast(message: "\(existing.name) is now logged and remains in your daily tracker", color: CloveColors.success)
        } else {
            SymptomManager.shared.addSymptom(name: trimmedName, isBinary: isBinary) {
                guard let symptom = SymptomsRepo.shared.getTrackedSymptoms().first(where: {
                    $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
                }), let id = symptom.id else { return }
                appendRating(id: id, name: symptom.name)
            }
        }

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        dismiss()
    }

    private func appendRating(id: Int64, name: String) {
        if let index = viewModel.logData.symptomRatings.firstIndex(where: { $0.symptomId == id }) {
            viewModel.logData.symptomRatings[index].ratingDouble = rating
            return
        }
        viewModel.logData.symptomRatings.append(SymptomRatingVM(
            symptomId: id,
            symptomName: name,
            ratingDouble: rating,
            isBinary: isBinary
        ))
    }

    /// Generates a consistent Int64 hash from a symptom name
    private func hashSymptomName(_ name: String) -> Int64 {
        let hash = SHA256.hash(data: Data(name.utf8))
        let hashBytes = Array(hash.prefix(8)) // Take first 8 bytes for Int64

        // Convert bytes to Int64
        var value: Int64 = 0
        for byte in hashBytes {
            value = value << 8
            value = value | Int64(byte)
        }

        return value
    }
}

#Preview {
    QuickAddSymptomSheet()
        .environment(TodayViewModel())
}
