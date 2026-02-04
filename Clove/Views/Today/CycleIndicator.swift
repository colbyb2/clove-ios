import SwiftUI

struct CycleIndicator: View {
    let cycle: Cycle
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false
    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // MARK: - Leading Icon
                // Visualizes flow intensity with color and scale
                ZStack {
                    Circle()
                        .fill(flowColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: flowIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(flowColor)
                }

                // MARK: - Main Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(cycle.flow.displayName)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(CloveColors.primary)
                    
                    // Metadata Row (Start of Cycle / Cramps)
                    if cycle.isStartOfCycle || cycle.hasCramps {
                        HStack(spacing: 12) {
                            if cycle.isStartOfCycle {
                                MetadataItem(
                                    icon: "arrow.counterclockwise",
                                    text: "Day 1",
                                    color: .blue
                                )
                            }
                            
                            if cycle.hasCramps {
                                MetadataItem(
                                    icon: "bolt.heart.fill",
                                    text: "Cramps",
                                    color: .orange
                                )
                            }
                        }
                    } else {
                        // Fallback text if no extra tags, to keep vertical rhythm
                        Text("Logged entry")
                            .font(.system(.caption))
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                }

                Spacer()

                // MARK: - Delete Action
                // Hit-tested separately to prevent triggering the main onTap
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(Color.gray.opacity(0.1)) // Subtle touch target
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle()) // Prevents parent click
            }
            .padding(12)
            .background(CloveColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            isPressed = pressing
        }, perform: onTap)
        .confirmationDialog(
            "Delete Entry?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                withAnimation { onDelete() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove this cycle log from your history.")
        }
    }

    // MARK: - Helper Logic
    
    private var flowColor: Color {
        switch cycle.flow {
        case .spotting: return .pink.opacity(0.6)
        case .light: return .pink
        case .medium: return .red
        case .heavy: return .red.opacity(0.9)
        case .veryHeavy: return .purple
        }
    }
    
    private var flowIcon: String {
        switch cycle.flow {
        case .spotting, .light: return "drop"
        case .medium, .heavy: return "drop.fill"
        case .veryHeavy: return "drop.triangle.fill"
        }
    }
}

// MARK: - Subcomponents

struct MetadataItem: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(UIColor.systemGroupedBackground).ignoresSafeArea()
        
        VStack(spacing: 16) {
            CycleIndicator(
                cycle: Cycle(
                    date: Date(),
                    flow: .heavy,
                    isStartOfCycle: true,
                    hasCramps: true
                ),
                onTap: {},
                onDelete: {}
            )
            
            CycleIndicator(
                cycle: Cycle(
                    date: Date(),
                    flow: .light,
                    isStartOfCycle: false,
                    hasCramps: false
                ),
                onTap: {},
                onDelete: {}
            )
            
            CycleIndicator(
                cycle: Cycle(
                    date: Date(),
                    flow: .spotting,
                    isStartOfCycle: false,
                    hasCramps: true
                ),
                onTap: {},
                onDelete: {}
            )
        }
        .padding()
    }
}
