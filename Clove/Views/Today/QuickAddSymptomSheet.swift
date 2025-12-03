//
//  QuickAddSymptomShet.swift
//  Clove
//
//  Created by Colby Brown on 12/3/25.
//

import SwiftUI
import CryptoKit

struct QuickAddSymptomSheet: View {
    @Environment(TodayViewModel.self) var viewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var symptomName: String = ""
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
                        Text("Add One-Time Symptom")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(CloveColors.primaryText)

                        Text("Log a symptom for today only")
                            .font(.system(.subheadline, design: .rounded))
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

                    // Save button
                    Button(action: {
                        saveSymptom()
                    }) {
                        HStack(spacing: CloveSpacing.small) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))

                            Text("Save Symptom")
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
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
    }

    private var isAddButtonEnabled: Bool {
        !symptomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveSymptom() {
        let trimmedName = symptomName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        // Generate consistent hash-based ID from symptom name
        let symptomId = hashSymptomName(trimmedName)
        viewModel.logData.symptomRatings.append(SymptomRatingVM(symptomId: symptomId, symptomName: trimmedName))

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        dismiss()
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
