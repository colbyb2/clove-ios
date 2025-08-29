import SwiftUI

struct BowelMovementSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let onUpdate: () -> Void
    
    @State private var notes: String = ""
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
                                isSelected: false
                            ) {
                                addBowelMovement(type: Double(type.rawValue))
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
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.shared.accent)
                }
            }
        }
        .onAppear {
            notes = "" // Reset notes for new entry
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                animateIn = true
            }
        }
    }
    
    private func addBowelMovement(type: Double) {
        let movement = BowelMovement(type: type, date: date, notes: notes.isEmpty ? nil : notes)
        
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
}

#Preview {
    BowelMovementSelectionSheet(date: Date(), onUpdate: {})
}
