import SwiftUI

struct BowelMovementTracker: View {
    let date: Date
    
    @State private var bowelMovements: [BowelMovement] = []
    @State private var showBowelMovementSelection: Bool = false
    
    private let repo = BowelMovementRepo.shared
    
    var body: some View {
        VStack(spacing: CloveSpacing.small) {
            // Main Header Row
            HStack {
                HStack(spacing: CloveSpacing.small) {
                    Text("🚽")
                        .font(.system(size: 20))
                    Text("Bowel Movements")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }
                
                Spacer()
                
                Button(action: {
                    showBowelMovementSelection = true
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }) {
                    HStack {
                        Text(bowelMovementButtonText())
                            .foregroundStyle(bowelMovements.isEmpty ? CloveColors.secondaryText : CloveColors.primaryText)
                            .font(.system(.body, design: .rounded).weight(.medium))
                        
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Theme.shared.accent)
                            .font(.system(size: 16))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(CloveColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
                    .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
                }
                .accessibilityLabel("Add bowel movement entry")
                .accessibilityHint("Opens bowel movement type selection")
            }
            
            // Today's Entries
            if !bowelMovements.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(bowelMovements) { movement in
                        HStack(spacing: 12) {
                            // Type Circle
                            ZStack {
                                Circle()
                                    .fill(Theme.shared.accent.opacity(0.1))
                                    .frame(width: 32, height: 32)
                                
                                Text("\(Int(movement.type))")
                                    .font(.system(.caption, design: .rounded).weight(.bold))
                                    .foregroundStyle(Theme.shared.accent)
                            }
                            
                            // Details
                            VStack(alignment: .leading, spacing: 2) {
                                Text(movement.bristolStoolType.description)
                                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                                    .foregroundStyle(CloveColors.primaryText)
                                
                                HStack {
                                    Text(movement.bristolStoolType.consistency)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(Theme.shared.accent)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(Theme.shared.accent.opacity(0.1))
                                        )
                                    
                                    Text(formatTime(movement.date))
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(CloveColors.secondaryText)
                                    
                                    Spacer()
                                }
                                
                                if let notes = movement.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.system(.caption))
                                        .foregroundStyle(CloveColors.secondaryText)
                                        .italic()
                                        .lineLimit(2)
                                }
                            }
                            
                            Spacer()
                            
                            // Delete Button
                            Button(action: {
                                deleteBowelMovement(movement)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(12)
                        .background(CloveColors.card.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
                    }
                }
            }
        }
        .padding(.vertical, CloveSpacing.small)
        .onAppear {
            loadBowelMovements()
        }
        .sheet(isPresented: $showBowelMovementSelection) {
            BowelMovementSelectionSheet(date: date) {
                loadBowelMovements()
            }
        }
    }
    
    private func bowelMovementButtonText() -> String {
        if bowelMovements.isEmpty {
            return "Tap to track"
        }
        
        let count = bowelMovements.count
        return "\(count)"
    }
    
    private func loadBowelMovements() {
        bowelMovements = repo.getBowelMovementsForDate(date)
    }
    
    private func deleteBowelMovement(_ movement: BowelMovement) {
        guard let id = movement.id else { return }
        
        if repo.delete(id: id) {
            loadBowelMovements()
            
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
    VStack {
        BowelMovementTracker(date: Date())
        Spacer()
    }
    .padding()
    .background(CloveColors.background)
}
