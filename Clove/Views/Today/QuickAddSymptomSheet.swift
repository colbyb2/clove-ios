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
        NavigationView {
            VStack(spacing: CloveSpacing.xlarge) {
                // Header with icon
                VStack(spacing: CloveSpacing.medium) {
                    ZStack {
                        Circle()
                            .fill(Theme.shared.accent.opacity(0.1))
                            .frame(width: 60, height: 60)

                        Image(systemName: "bandage.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(Theme.shared.accent)
                    }

                    VStack(spacing: CloveSpacing.small) {
                        Text("Log a Symptom")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(CloveColors.primaryText)

                        Text("Choose whether this is occasional or something you want to track regularly")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(CloveColors.secondaryText)
                    }

                    VStack(alignment: .leading, spacing: CloveSpacing.small) {
                        Text("How would you like to track this?")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(CloveColors.secondaryText)
                        Picker("Tracking frequency", selection: $trackingScope) {
                            ForEach(TrackingScope.allCases) { scope in Text(scope.rawValue).tag(scope) }
                        }
                        .pickerStyle(.segmented)
                        Text(trackingScope == .todayOnly
                             ? "Saved only to \(viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted))."
                             : "Added to your daily tracker and logged for this date.")
                            .font(.caption)
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                }
                .padding(.top, CloveSpacing.large)

                // Input section
                VStack(alignment: .leading, spacing: CloveSpacing.medium) {
                    VStack(alignment: .leading, spacing: CloveSpacing.small) {
                        Text("Symptom Name")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(CloveColors.secondaryText)

                        TextField("e.g., Headache, Nausea", text: $symptomName)
                            .font(.system(.body, design: .rounded))
                            .padding(CloveSpacing.medium)
                            .background(
                                RoundedRectangle(cornerRadius: CloveCorners.medium)
                                    .fill(CloveColors.background)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                                            .stroke(
                                                isTextFieldFocused ? Theme.shared.accent.opacity(0.5) : CloveColors.secondaryText.opacity(0.2),
                                                lineWidth: 1.5
                                            )
                                    )
                            )
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                if isAddButtonEnabled {
                                    saveSymptom()
                                }
                            }
                    }

                    // Rating scale toggle
                    VStack(alignment: .leading, spacing: CloveSpacing.small) {
                        Text("Rating Scale")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(CloveColors.secondaryText)

                        HStack(spacing: CloveSpacing.small) {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isBinary = false
                                }
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }) {
                                HStack(spacing: CloveSpacing.small) {
                                    Text("0-10")
                                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(!isBinary ? .white : CloveColors.primaryText)
                                .background(
                                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                                        .fill(!isBinary ? Theme.shared.accent : CloveColors.background)
                                )
                            }

                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isBinary = true
                                }
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }) {
                                HStack(spacing: CloveSpacing.small) {
                                    Text("Yes/No")
                                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(isBinary ? .white : CloveColors.primaryText)
                                .background(
                                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                                        .fill(isBinary ? Theme.shared.accent : CloveColors.background)
                                )
                            }
                        }

                        Text(isBinary ? "Log a 'Yes' or 'No' response for this date" : "Rate the symptom on a 0-10 scale for this date")
                            .font(.caption)
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                    .onChange(of: isBinary) { _, binary in
                        rating = binary ? 10 : 5
                    }

                    VStack(alignment: .leading, spacing: CloveSpacing.small) {
                        Text("Value for this date")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(CloveColors.secondaryText)
                        if isBinary {
                            Picker("Symptom status", selection: $rating) {
                                Text("No").tag(0.0)
                                Text("Yes").tag(10.0)
                            }
                            .pickerStyle(.segmented)
                        } else {
                            HStack {
                                Slider(value: $rating, in: 0...10, step: 1)
                                    .tint(Theme.shared.accent)
                                Text("\(Int(rating))")
                                    .font(.title3.bold())
                                    .foregroundStyle(Theme.shared.accent)
                                    .frame(width: 28)
                            }
                        }
                    }

                    // Save button
                    Button(action: {
                        saveSymptom()
                    }) {
                        HStack(spacing: CloveSpacing.small) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))

                            Text(trackingScope == .todayOnly ? "Log for This Day" : "Track Daily & Log")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: CloveCorners.medium)
                                .fill(
                                    isAddButtonEnabled ? Theme.shared.accent : CloveColors.secondaryText.opacity(0.5)
                                )
                                .shadow(
                                    color: isAddButtonEnabled ? Theme.shared.accent.opacity(0.3) : .clear,
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                        )
                        .scaleEffect(isAddButtonEnabled ? 1.0 : 0.95)
                        .opacity(isAddButtonEnabled ? 1.0 : 0.6)
                    }
                    .disabled(!isAddButtonEnabled)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isAddButtonEnabled)
                }
                .padding(.horizontal, CloveSpacing.large)

                Spacer()
            }
            .background(CloveColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(CloveColors.secondaryText)
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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
