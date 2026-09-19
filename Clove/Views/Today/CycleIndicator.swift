import SwiftUI

struct TodayCycleCard: View {
    let date: Date
    let entry: Cycle?
    let cycleDay: Int?
    let isPeriodActive: Bool
    let onLog: (CycleEntryPreset?) -> Void
    let onDelete: () -> Void
    let onHide: () -> Void

    var body: some View {
        if entry == nil && !isPeriodActive {
            compactCard
        } else {
            activeCard
        }
    }

    private var compactCard: some View {
        HStack(spacing: CloveSpacing.small) {
            Image(systemName: CloveSymbols.cycle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.pink)
                .frame(width: 34, height: 34)
                .background(Color.pink.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("Cycle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CloveColors.primaryText)
                Text("No active period")
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)
            }

            Spacer()

            NavigationLink {
                CycleOverviewView()
            } label: {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.shared.accent)
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Cycle overview")

            Button("Log period") { onLog(.start) }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(Theme.shared.accent)
                .accessibilityHint("Open a cycle entry with Period Started selected")

            Menu {
                Button("Hide from Today", systemImage: "eye.slash", action: onHide)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CloveColors.secondaryText)
                    .frame(width: 30, height: 38)
                    .contentShape(Rectangle())
            }
        }
        .padding(CloveSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
    }

    private var activeCard: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            HStack(spacing: CloveSpacing.small) {
                Image(systemName: CloveSymbols.cycle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.pink)
                    .frame(width: 36, height: 36)
                    .background(Color.pink.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Cycle")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(CloveColors.primaryText)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(CloveColors.secondaryText)
                }

                Spacer()

                NavigationLink {
                    CycleOverviewView()
                } label: {
                    HStack(spacing: 4) {
                        Text("Overview")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.shared.accent)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .accessibilityHint("View cycle history and predictions")

                Menu {
                    Button("Hide from Today", systemImage: "eye.slash", action: onHide)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CloveColors.secondaryText)
                        .frame(width: 30, height: 38)
                        .contentShape(Rectangle())
                }
            }

            if let entry {
                CycleIndicator(
                    cycle: entry,
                    onTap: { onLog(nil) },
                    onDelete: onDelete
                )
            } else {
                HStack(spacing: CloveSpacing.small) {
                    Button {
                        onLog(nil)
                    } label: {
                        Label("Log today", systemImage: "drop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.shared.accent)
                    .accessibilityHint("Record flow details for this day")

                    Button {
                        onLog(.end)
                    } label: {
                        Label("End period", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.shared.accent)
                    .accessibilityHint("Open a cycle entry with Period Ended selected")
                }

                Text("Record an in-between day, or mark this as the final day.")
                    .font(.caption2)
                    .foregroundStyle(CloveColors.secondaryText)
            }
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
        .accessibilityElement(children: .contain)
    }

    private var statusText: String {
        if let entry {
            if entry.isStartOfCycle { return "Period started on this day" }
            if entry.isEndOfCycle == true { return "Period ended on this day" }
            return "Period details logged"
        }
        if isPeriodActive, let cycleDay { return "Period day \(cycleDay) • Nothing logged today" }
        return "Nothing logged for this day"
    }
}

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
