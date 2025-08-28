import SwiftUI

struct BowelMovementTracker: View {
    let date: Date
    
    @State private var bowelMovements: [BowelMovement] = []
    @State private var showBowelMovementSelection: Bool = false
    
    private let repo = BowelMovementRepo.shared
    
    var body: some View {
        VStack(spacing: CloveSpacing.small) {
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
                        Text(bowelMovementSummaryText())
                            .foregroundStyle(bowelMovements.isEmpty ? CloveColors.secondaryText : CloveColors.primary)
                            .font(.system(.body, design: .rounded).weight(.medium))
                        
                        if bowelMovements.isEmpty {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Theme.shared.accent)
                                .font(.system(size: 16))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(CloveColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
                    .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
                }
                .accessibilityLabel("Bowel movement tracking")
                .accessibilityHint("Opens bowel movement type selection")
            }
        }
        .padding(.vertical, CloveSpacing.small)
        .onAppear {
            loadBowelMovements()
        }
        .sheet(isPresented: $showBowelMovementSelection) {
            // Placeholder sheet - will be replaced with actual selection view
            VStack(spacing: 20) {
                Text("Bowel Movement Selection")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Bristol Stool Chart Selection")
                    .font(.body)
                    .foregroundStyle(CloveColors.secondaryText)
                
                Text("Placeholder - Selection interface will go here")
                    .padding()
                    .background(CloveColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: CloveCorners.medium))
                
                Button("Cancel") {
                    showBowelMovementSelection = false
                }
                .foregroundStyle(Theme.shared.accent)
                
                Spacer()
            }
            .padding()
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
    
    private func bowelMovementSummaryText() -> String {
        if bowelMovements.isEmpty {
            return "Tap to track"
        }
        
        let count = bowelMovements.count
        return count == 1 ? "1 entry" : "\(count) entries"
    }
    
    private func loadBowelMovements() {
        bowelMovements = repo.getBowelMovementsForDate(date)
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
