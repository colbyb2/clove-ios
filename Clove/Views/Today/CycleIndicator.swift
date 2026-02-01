import SwiftUI

struct CycleIndicator: View {
    let cycle: Cycle
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: CloveSpacing.medium) {
                // Icon
                Text("🩸")
                    .font(.system(size: 24))

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Cycle: \(cycle.flow.displayName)")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(CloveColors.primary)

                        // Badges
                        if cycle.isStartOfCycle {
                            Badge(text: "First Day", color: CloveColors.accent)
                        }

                        if cycle.hasCramps {
                            Badge(text: "Cramps", color: CloveColors.orange)
                        }
                    }

                    Text(flowDescription(for: cycle.flow))
                        .font(.system(.caption))
                        .foregroundStyle(CloveColors.secondaryText)
                }

                Spacer()

                // Delete button
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(CloveColors.card)
            .clipShape(RoundedRectangle(cornerRadius: CloveCorners.medium))
            .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .confirmationDialog(
            "Delete cycle entry?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove this cycle entry.")
        }
        .accessibilityLabel("Cycle entry: \(cycle.flow.displayName)")
        .accessibilityHint("Tap to edit, or tap delete button to remove")
    }

    private func flowDescription(for flow: FlowLevel) -> String {
        switch flow {
        case .spotting: return "Very light bleeding"
        case .light: return "Light flow"
        case .medium: return "Moderate flow"
        case .heavy: return "Heavy flow"
        case .veryHeavy: return "Very heavy flow"
        }
    }
}

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color)
            )
    }
}

#Preview {
    VStack(spacing: 16) {
        CycleIndicator(
            cycle: Cycle(
                date: Date(),
                flow: .medium,
                isStartOfCycle: true,
                hasCramps: true
            ),
            onTap: {
                print("Tapped cycle indicator")
            },
            onDelete: {
                print("Delete cycle entry")
            }
        )

        CycleIndicator(
            cycle: Cycle(
                date: Date(),
                flow: .light,
                isStartOfCycle: false,
                hasCramps: false
            ),
            onTap: {
                print("Tapped cycle indicator")
            },
            onDelete: {
                print("Delete cycle entry")
            }
        )
    }
    .padding()
    .background(CloveColors.background)
}
