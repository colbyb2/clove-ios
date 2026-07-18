import SwiftUI

struct BowelMovementSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let existingMovement: BowelMovement?
    let onUpdate: () -> Void
    
    @State private var notes: String = ""
    @State private var selectedType: BristolStoolType?
    @State private var movementDate: Date = Date()
    @State private var animateIn = false
    
    private let repo = BowelMovementRepo.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Bristol Stool Chart")
                            .font(.system(.title2, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.shared.accent)
                        
                        Text("Select the type that best matches")
                            .font(.system(.subheadline))
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                    .multilineTextAlignment(.center)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : -20)
                    
                    // Bristol Chart Types
                    // Notes Input Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes (Optional)")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.shared.accent)
                        
                        TextField("Add any additional notes...", text: $notes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3, reservesSpace: true)

                        DatePicker("Time", selection: $movementDate, displayedComponents: .hourAndMinute)
                    }
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 10)
                    
                    // Bristol Chart Types
                    VStack(spacing: 12) {
                        Text("Select Bristol Stool Chart Type")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.shared.accent)
                        
                        ForEach(BristolStoolType.allCases, id: \.rawValue) { type in
                            BristolChartCard(
                                type: type,
                                isSelected: selectedType == type
                            ) {
                                if existingMovement == nil {
                                    saveBowelMovement(type: type)
                                } else {
                                    selectedType = type
                                }
                            }
                        }
                    }
                    .opacity(animateIn ? 1 : 0)
                    .scaleEffect(animateIn ? 1 : 0.95)
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if existingMovement != nil {
                        Button("Save") { saveEditedBowelMovement() }
                            .fontWeight(.semibold)
                            .disabled(selectedType == nil)
                            .foregroundStyle(Theme.shared.accent)
                    } else {
                        Button("Done") { dismiss() }
                            .foregroundStyle(Theme.shared.accent)
                    }
                }
            }
        }
        .onAppear {
            notes = existingMovement?.notes ?? ""
            selectedType = existingMovement?.bristolStoolType
            movementDate = existingMovement?.date ?? date
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                animateIn = true
            }
        }
    }
    
    private func saveBowelMovement(type: BristolStoolType) {
        let movement = BowelMovement(type: Double(type.rawValue), date: movementDate, notes: notes.emptyToNil)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        if repo.save([movement]) {
            onUpdate()
            
            // Success haptic
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
            
            // Dismiss after brief delay to show selection
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
        }
    }

    private func saveEditedBowelMovement() {
        guard var movement = existingMovement, let selectedType else { return }
        movement.type = Double(selectedType.rawValue)
        movement.notes = notes.emptyToNil
        movement.date = movementDate

        if repo.update(movement) {
            onUpdate()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        }
    }
}

private extension String {
    var emptyToNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    BowelMovementSelectionSheet(date: Date(), existingMovement: nil, onUpdate: {})
}
