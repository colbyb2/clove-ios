import SwiftUI

struct InsightsCustomizationView: View {
    @AppStorage(Constants.INSIGHTS_OVERVIEW_DASHBOARD) private var overviewDashboard: Bool = true
    @AppStorage(Constants.INSIGHTS_SMART_INSIGHTS) private var smartInsights: Bool = true
    @AppStorage(Constants.INSIGHTS_METRIC_CHARTS) private var metricCharts: Bool = true
    @AppStorage(Constants.INSIGHTS_CORRELATIONS) private var correlations: Bool = true
    
    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var presetsOpacity: Double = 0
    @State private var togglesOpacity: Double = 0
    @State private var headerOffset: CGFloat = -20
    @State private var presetsOffset: CGFloat = 30
    @State private var togglesOffset: CGFloat = 30
    @State private var presetAnimations: [Bool] = Array(repeating: false, count: 3)
    @State private var toggleAnimations: [Bool] = Array(repeating: false, count: 4)
    
    var body: some View {
        ZStack {
            // Subtle gradient background
            LinearGradient(
                colors: [
                    Theme.shared.accent.opacity(0.02),
                    CloveColors.background,
                    Theme.shared.accent.opacity(0.01)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: CloveSpacing.xlarge) {
                    // Enhanced header explanation
                    headerSection
                        .opacity(headerOpacity)
                        .offset(y: headerOffset)
                    
                    // Enhanced complexity presets
                    complexityPresetsSection
                        .opacity(presetsOpacity)
                        .offset(y: presetsOffset)
                    
                    // Enhanced individual toggles
                    individualTogglesSection
                        .opacity(togglesOpacity)
                        .offset(y: togglesOffset)
                }
                .padding(.horizontal, CloveSpacing.large)
                .padding(.bottom, CloveSpacing.xlarge)
            }
        }
        .navigationTitle("Customize Insights")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startEntranceAnimations()
        }
    }
    
    // MARK: - Animation Helpers
    
    private func startEntranceAnimations() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            headerOpacity = 1.0
            headerOffset = 0
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
            presetsOpacity = 1.0
            presetsOffset = 0
        }
        
        // Animate preset cards individually
        for i in 0..<presetAnimations.count {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2 + Double(i) * 0.1)) {
                presetAnimations[i] = true
            }
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
            togglesOpacity = 1.0
            togglesOffset = 0
        }
        
        // Animate toggle rows individually
        for i in 0..<toggleAnimations.count {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.5 + Double(i) * 0.05)) {
                toggleAnimations[i] = true
            }
        }
    }
    
    // MARK: - Enhanced Header Section
    
    private var headerSection: some View {
        VStack(spacing: CloveSpacing.large) {
            // Icon and title
            HStack(spacing: CloveSpacing.medium) {
                ZStack {
                    Circle()
                        .fill(Theme.shared.accent.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Theme.shared.accent)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Insights Complexity")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("Choose your comfort level")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
            }
            
            // Description
            VStack(alignment: .leading, spacing: CloveSpacing.small) {
                Text("Customize your insights experience to match your preferences. You can always change these settings later.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(CloveColors.secondaryText)
                    .lineSpacing(2)
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - Enhanced Complexity Presets Section
    
    private var complexityPresetsSection: some View {
        VStack(spacing: CloveSpacing.large) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Setup")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("Choose a preset configuration")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
            }
            
            VStack(spacing: CloveSpacing.medium) {
                EnhancedComplexityPresetCard(
                    title: "Simple",
                    description: "Basic charts only",
                    detailedDescription: "Perfect for getting started",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green,
                    isSelected: isSimpleMode,
                    onTap: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            setSimpleMode()
                        }
                    }
                )
                .opacity(presetAnimations.indices.contains(0) ? (presetAnimations[0] ? 1.0 : 0) : 0)
                .scaleEffect(presetAnimations.indices.contains(0) ? (presetAnimations[0] ? 1.0 : 0.9) : 0.9)
                
                EnhancedComplexityPresetCard(
                    title: "Balanced",
                    description: "Charts with smart insights",
                    detailedDescription: "Great balance of detail and simplicity",
                    icon: "chart.bar.doc.horizontal",
                    color: .blue,
                    isSelected: isBalancedMode,
                    onTap: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            setBalancedMode()
                        }
                    }
                )
                .opacity(presetAnimations.indices.contains(1) ? (presetAnimations[1] ? 1.0 : 0) : 0)
                .scaleEffect(presetAnimations.indices.contains(1) ? (presetAnimations[1] ? 1.0 : 0.9) : 0.9)
                
                EnhancedComplexityPresetCard(
                    title: "Advanced",
                    description: "All features including correlations",
                    detailedDescription: "For comprehensive health analytics",
                    icon: "brain.head.profile",
                    color: .purple,
                    isSelected: isAdvancedMode,
                    onTap: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            setAdvancedMode()
                        }
                    }
                )
                .opacity(presetAnimations.indices.contains(2) ? (presetAnimations[2] ? 1.0 : 0) : 0)
                .scaleEffect(presetAnimations.indices.contains(2) ? (presetAnimations[2] ? 1.0 : 0.9) : 0.9)
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - Enhanced Individual Toggles Section
    
    private var individualTogglesSection: some View {
        VStack(spacing: CloveSpacing.large) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Individual Features")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("Fine-tune each feature")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
            }
            
            VStack(spacing: CloveSpacing.medium) {
                EnhancedInsightToggleRow(
                    title: "Overview Dashboard",
                    description: "Quick summary cards of your key health metrics",
                    icon: "square.grid.2x2",
                    color: .blue,
                    isEnabled: overviewDashboard,
                    onToggle: { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            overviewDashboard = value
                        }
                    }
                )
                .opacity(toggleAnimations.indices.contains(0) ? (toggleAnimations[0] ? 1.0 : 0) : 0)
                .offset(x: toggleAnimations.indices.contains(0) ? (toggleAnimations[0] ? 0 : 20) : 20)
                
                EnhancedInsightToggleRow(
                    title: "Metric Charts",
                    description: "Interactive charts for exploring your data trends",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green,
                    isEnabled: metricCharts,
                    onToggle: { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            metricCharts = value
                        }
                    }
                )
                .opacity(toggleAnimations.indices.contains(1) ? (toggleAnimations[1] ? 1.0 : 0) : 0)
                .offset(x: toggleAnimations.indices.contains(1) ? (toggleAnimations[1] ? 0 : 20) : 20)
                
                EnhancedInsightToggleRow(
                    title: "Smart Insights",
                    description: "AI-powered analysis and pattern recognition",
                    icon: "brain.head.profile",
                    color: .orange,
                    isEnabled: smartInsights,
                    onToggle: { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            smartInsights = value
                        }
                    }
                )
                .opacity(toggleAnimations.indices.contains(2) ? (toggleAnimations[2] ? 1.0 : 0) : 0)
                .offset(x: toggleAnimations.indices.contains(2) ? (toggleAnimations[2] ? 0 : 20) : 20)
                
                EnhancedInsightToggleRow(
                    title: "Cross-Reference Analysis",
                    description: "Advanced correlation analysis between metrics",
                    icon: "chart.bar.xaxis",
                    color: .purple,
                    isEnabled: correlations,
                    onToggle: { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            correlations = value
                        }
                    }
                )
                .opacity(toggleAnimations.indices.contains(3) ? (toggleAnimations[3] ? 1.0 : 0) : 0)
                .offset(x: toggleAnimations.indices.contains(3) ? (toggleAnimations[3] ? 0 : 20) : 20)
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - Helper Properties
    
    private var isSimpleMode: Bool {
        metricCharts && !smartInsights && !correlations && !overviewDashboard
    }
    
    private var isBalancedMode: Bool {
        metricCharts && smartInsights && overviewDashboard && !correlations
    }
    
    private var isAdvancedMode: Bool {
        metricCharts && smartInsights && overviewDashboard && correlations
    }
    
    // MARK: - Helper Methods
    
    private func setSimpleMode() {
        overviewDashboard = false
        smartInsights = false
        metricCharts = true
        correlations = false
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func setBalancedMode() {
        overviewDashboard = true
        smartInsights = true
        metricCharts = true
        correlations = false
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func setAdvancedMode() {
        overviewDashboard = true
        smartInsights = true
        metricCharts = true
        correlations = true
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Enhanced Supporting Views

struct EnhancedComplexityPresetCard: View {
    let title: String
    let description: String
    let detailedDescription: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: CloveSpacing.medium) {
                // Enhanced icon
                ZStack {
                    Circle()
                        .fill(isSelected ? color : color.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? color.opacity(0.3) : color.opacity(0.2), lineWidth: 2)
                        )
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? .white : color)
                }
                
                // Content
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    Text(title)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text(description)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                    
                    Text(detailedDescription)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText.opacity(0.8))
                        .italic()
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(color)
                        .scaleEffect(1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                }
            }
            .padding(CloveSpacing.large)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.large)
                    .fill(
                        isSelected ?
                        LinearGradient(
                            colors: [color.opacity(0.08), color.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [CloveColors.background, CloveColors.background],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CloveCorners.large)
                            .stroke(
                                isSelected ? color.opacity(0.3) : color.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.02 : (isPressed ? 0.98 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

struct EnhancedInsightToggleRow: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: CloveSpacing.medium) {
            // Enhanced icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: CloveSpacing.small) {
                Text(title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Text(description)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(CloveColors.secondaryText)
                    .lineLimit(2)
                    .lineSpacing(1)
            }
            
            Spacer()
            
            // Enhanced toggle
            Button(action: {
                onToggle(!isEnabled)
                
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isEnabled ? color : CloveColors.secondaryText.opacity(0.3))
                        .frame(width: 50, height: 30)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isEnabled)
                    
                    Circle()
                        .fill(.white)
                        .frame(width: 26, height: 26)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .offset(x: isEnabled ? 10 : -10)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isEnabled)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.large)
                        .stroke(
                            isEnabled ? color.opacity(0.2) : CloveColors.secondaryText.opacity(0.1),
                            lineWidth: 1
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isEnabled)
                )
        )
    }
}

#Preview {
    NavigationView {
        InsightsCustomizationView()
    }
}
