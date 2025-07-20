import SwiftUI

struct InsightsComplexityOnboardingView: View {
    @Environment(OnboardingViewModel.self) var viewModel
    @AppStorage(Constants.INSIGHTS_OVERVIEW_DASHBOARD) private var overviewDashboard: Bool = true
    @AppStorage(Constants.INSIGHTS_SMART_INSIGHTS) private var smartInsights: Bool = true
    @AppStorage(Constants.INSIGHTS_METRIC_CHARTS) private var metricCharts: Bool = true
    @AppStorage(Constants.INSIGHTS_CORRELATIONS) private var correlations: Bool = true
    
    @State private var selectedComplexity: ComplexityLevel = .balanced
    
    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var headerOffset: CGFloat = -20
    @State private var optionsOpacity: Double = 0
    @State private var optionsOffset: CGFloat = 30
    @State private var buttonOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 30
    @State private var optionAnimations: [Bool] = Array(repeating: false, count: 3)
    
    enum ComplexityLevel: String, CaseIterable {
        case simple = "Simple"
        case balanced = "Balanced"
        case comprehensive = "Comprehensive"
        
        var description: String {
            switch self {
            case .simple:
                return "Essential insights with clean, easy-to-read charts"
            case .balanced:
                return "Moderate detail with helpful patterns and trends"
            case .comprehensive:
                return "Detailed analysis with correlations and advanced metrics"
            }
        }
        
        var detailedDescription: String {
            switch self {
            case .simple:
                return "Perfect for beginners who want basic health tracking"
            case .balanced:
                return "Great balance of simplicity and useful insights"
            case .comprehensive:
                return "For users who want deep health analytics"
            }
        }
        
        var icon: String {
            switch self {
            case .simple:
                return "chart.bar"
            case .balanced:
                return "chart.line.uptrend.xyaxis"
            case .comprehensive:
                return "chart.bar.doc.horizontal"
            }
        }
        
        var color: Color {
            switch self {
            case .simple:
                return .green
            case .balanced:
                return .blue
            case .comprehensive:
                return .purple
            }
        }
        
        var features: [String] {
            switch self {
            case .simple:
                return ["Basic charts", "Simple summaries", "Essential metrics"]
            case .balanced:
                return ["Trend analysis", "Pattern detection", "Weekly insights", "Health scores"]
            case .comprehensive:
                return ["Correlation analysis", "Advanced metrics", "Predictive insights", "Detailed reports", "Export options"]
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Subtle gradient background
            LinearGradient(
                colors: [
                    Theme.shared.accent.opacity(0.02),
                    CloveColors.background,
                    selectedComplexity.color.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: selectedComplexity)
            
            ScrollView {
                VStack(spacing: CloveSpacing.xlarge) {
                    // Enhanced Header
                    VStack(spacing: CloveSpacing.large) {
                        // Main icon with animated background
                        ZStack {
                            Circle()
                                .fill(selectedComplexity.color.opacity(0.1))
                                .frame(width: 80, height: 80)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedComplexity)
                            
                            Circle()
                                .fill(selectedComplexity.color.opacity(0.05))
                                .frame(width: 60, height: 60)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedComplexity)
                            
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(selectedComplexity.color)
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedComplexity)
                        }
                        
                        // Title and description
                        VStack(spacing: CloveSpacing.medium) {
                            Text("Choose Your Insights Level")
                                .font(.system(.title, design: .rounded, weight: .bold))
                                .foregroundStyle(CloveColors.primaryText)
                                .multilineTextAlignment(.center)
                            
                            Text("Select how detailed you want your health insights to be. You can always change this later in Settings. Starting simple can keep you from getting overwhelmed!")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(CloveColors.secondaryText)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                        }
                        .padding(.horizontal, CloveSpacing.large)
                    }
                    .opacity(headerOpacity)
                    .offset(y: headerOffset)
                    
                    // Enhanced complexity options
                    VStack(spacing: CloveSpacing.large) {
                        ForEach(Array(ComplexityLevel.allCases.enumerated()), id: \.element) { index, complexity in
                            EnhancedComplexityOptionView(
                                complexity: complexity,
                                isSelected: selectedComplexity == complexity
                            ) {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    selectedComplexity = complexity
                                }
                                applyComplexitySettings(complexity)
                                
                                // Haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                            .opacity(optionAnimations[index] ? 1.0 : 0)
                            .scaleEffect(optionAnimations[index] ? 1.0 : 0.9)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: optionAnimations[index])
                        }
                    }
                    .padding(.horizontal, CloveSpacing.large)
                    .opacity(optionsOpacity)
                    .offset(y: optionsOffset)
                    
                    Spacer(minLength: CloveSpacing.medium)
                    
                    // Enhanced continue button
                    VStack(spacing: CloveSpacing.small) {
                        Button(action: {
                            viewModel.nextStep()
                            
                            // Enhanced haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        }) {
                            HStack(spacing: CloveSpacing.small) {
                                Text("Continue with \(selectedComplexity.rawValue)")
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: CloveCorners.large)
                                    .fill(
                                        LinearGradient(
                                            colors: [selectedComplexity.color, selectedComplexity.color.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: selectedComplexity.color.opacity(0.3), radius: 12, x: 0, y: 6)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedComplexity)
                            )
                        }
                        
                        Text("You can change this anytime in Settings")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                    .padding(.horizontal, CloveSpacing.large)
                    .padding(.bottom, CloveSpacing.large)
                    .opacity(buttonOpacity)
                    .offset(y: buttonOffset)
                }
            }
        }
        .onAppear {
            // Set default to balanced
            applyComplexitySettings(.balanced)
            startEntranceAnimations()
        }
    }
    
    private func startEntranceAnimations() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            headerOpacity = 1.0
            headerOffset = 0
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
            optionsOpacity = 1.0
            optionsOffset = 0
        }
        
        // Animate options individually
        for i in 0..<optionAnimations.count {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2 + Double(i) * 0.1)) {
                optionAnimations[i] = true
            }
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6)) {
            buttonOpacity = 1.0
            buttonOffset = 0
        }
    }
    
    private func applyComplexitySettings(_ complexity: ComplexityLevel) {
        switch complexity {
        case .simple:
            overviewDashboard = true
            smartInsights = false
            metricCharts = true
            correlations = false
        case .balanced:
            overviewDashboard = true
            smartInsights = true
            metricCharts = true
            correlations = false
        case .comprehensive:
            overviewDashboard = true
            smartInsights = true
            metricCharts = true
            correlations = true
        }
    }
}

struct EnhancedComplexityOptionView: View {
    let complexity: InsightsComplexityOnboardingView.ComplexityLevel
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                onTap()
            }
        }) {
            VStack(spacing: CloveSpacing.large) {
                HStack(spacing: CloveSpacing.medium) {
                    // Enhanced icon
                    ZStack {
                        Circle()
                            .fill(isSelected ? complexity.color : complexity.color.opacity(0.1))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(isSelected ? complexity.color.opacity(0.3) : complexity.color.opacity(0.2), lineWidth: 2)
                            )
                        
                        Image(systemName: complexity.icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(isSelected ? .white : complexity.color)
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: CloveSpacing.small) {
                        HStack {
                            Text(complexity.rawValue)
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(CloveColors.primaryText)
                            
                            Spacer()
                            
                            // Selection indicator
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(complexity.color)
                                    .scaleEffect(1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                            }
                        }
                        
                        Text(complexity.description)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(CloveColors.secondaryText)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(1)
                        
                        Text(complexity.detailedDescription)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(CloveColors.secondaryText.opacity(0.8))
                            .italic()
                    }
                }
                
                // Feature list for selected option
                if isSelected {
                    VStack(alignment: .leading, spacing: CloveSpacing.small) {
                        HStack {
                            Text("Includes:")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(complexity.color)
                            Spacer()
                        }
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible(), alignment: .leading),
                            GridItem(.flexible(), alignment: .leading)
                        ], spacing: CloveSpacing.xsmall) {
                            ForEach(complexity.features, id: \.self) { feature in
                                HStack(spacing: CloveSpacing.xsmall) {
                                    Circle()
                                        .fill(complexity.color)
                                        .frame(width: 4, height: 4)
                                    
                                    Text(feature)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(CloveColors.secondaryText)
                                    
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(.top, CloveSpacing.small)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
                }
            }
            .padding(CloveSpacing.large)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.large)
                    .fill(
                        isSelected ?
                        LinearGradient(
                            colors: [complexity.color.opacity(0.08), complexity.color.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [CloveColors.card, CloveColors.card],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CloveCorners.large)
                            .stroke(
                                isSelected ? complexity.color.opacity(0.3) : complexity.color.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isSelected ? complexity.color.opacity(0.15) : .black.opacity(0.05),
                        radius: isSelected ? 12 : 8,
                        x: 0,
                        y: isSelected ? 6 : 4
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
        .accessibilityLabel("\(complexity.rawValue) complexity level")
        .accessibilityHint(complexity.description)
    }
}

#Preview {
    InsightsComplexityOnboardingView()
        .environment(OnboardingViewModel())
}
