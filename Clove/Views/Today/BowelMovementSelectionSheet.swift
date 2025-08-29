import SwiftUI

struct BowelMovementSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let onUpdate: () -> Void
    
    @State private var bowelMovements: [BowelMovement] = []
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
                            .foregroundStyle(CloveColors.primary)
                        
                        Text("Select the type that best matches")
                            .font(.system(.subheadline))
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                    .multilineTextAlignment(.center)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : -20)
                    
                    // Bristol Chart Types
                    VStack(spacing: 12) {
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
                    
                    // Today's Entries
                    if !bowelMovements.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Today's Entries")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(CloveColors.primary)
                            
                            ForEach(bowelMovements) { movement in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Type \(Int(movement.type))")
                                            .font(.system(.body, design: .rounded).weight(.medium))
                                        
                                        Text(movement.bristolStoolType.description)
                                            .font(.system(.caption))
                                            .foregroundStyle(CloveColors.secondaryText)
                                        
                                        if let notes = movement.notes, !notes.isEmpty {
                                            Text(notes)
                                                .font(.system(.caption))
                                                .foregroundStyle(CloveColors.secondaryText)
                                                .italic()
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Text(formatTime(movement.date))
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(CloveColors.secondaryText)
                                    
                                    Button(action: {
                                        deleteBowelMovement(movement)
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding()
                                .background(CloveColors.card)
                                .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
                            }
                        }
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)
                    }
                    
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
            loadBowelMovements()
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                animateIn = true
            }
        }
    }
    
    private func loadBowelMovements() {
        bowelMovements = repo.getBowelMovementsForDate(date)
    }
    
    private func addBowelMovement(type: Double) {
        let movement = BowelMovement(type: type, date: Date(), notes: notes.isEmpty ? nil : notes)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        if repo.save([movement]) {
            loadBowelMovements()
            onUpdate()
            notes = ""
            
            // Success haptic
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
        }
    }
    
    private func deleteBowelMovement(_ movement: BowelMovement) {
        guard let id = movement.id else { return }
        
        if repo.delete(id: id) {
            loadBowelMovements()
            onUpdate()
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    BowelMovementSelectionSheet(date: Date(), onUpdate: {})
}