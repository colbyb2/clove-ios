import SwiftUI

struct InsightsCustomizationView: View {
   
   @AppStorage(Constants.INSIGHTS_OVERVIEW_DASHBOARD) private var overviewDashboard: Bool = true
   @AppStorage(Constants.INSIGHTS_SMART_INSIGHTS) private var smartInsights: Bool = true
   @AppStorage(Constants.INSIGHTS_METRIC_CHARTS) private var metricCharts: Bool = true
   @AppStorage(Constants.INSIGHTS_CORRELATIONS) private var correlations: Bool = true
   
   var body: some View {
      ScrollView {
         VStack(spacing: CloveSpacing.large) {
            // Header explanation
            headerSection
            
            // Complexity presets
            complexityPresetsSection
            
            // Individual toggles
            individualTogglesSection
         }
         .padding(.horizontal, CloveSpacing.large)
         .padding(.bottom, CloveSpacing.xlarge)
      }
      .background(CloveColors.background.ignoresSafeArea())
      .navigationTitle("Customize Insights")
      .navigationBarTitleDisplayMode(.inline)
   }
   
   // MARK: - Header Section
   
   private var headerSection: some View {
      VStack(alignment: .leading, spacing: CloveSpacing.medium) {
         HStack {
            Image(systemName: "slider.horizontal.3")
               .font(.system(size: 24))
               .foregroundStyle(Theme.shared.accent)
            
            VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
               Text("Insights Complexity")
                  .font(.system(.title2, design: .rounded).weight(.bold))
                  .foregroundStyle(CloveColors.primaryText)
               
               Text("Choose how much detail you want in your health insights")
                  .font(CloveFonts.body())
                  .foregroundStyle(CloveColors.secondaryText)
            }
            
            Spacer()
         }
         
         Text("Customize your insights experience to match your comfort level. You can always change these settings later.")
            .font(CloveFonts.small())
            .foregroundStyle(CloveColors.secondaryText)
            .padding(.top, CloveSpacing.small)
      }
      .padding(CloveSpacing.large)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.medium)
            .fill(CloveColors.card)
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
      )
   }
   
   // MARK: - Complexity Presets Section
   
   private var complexityPresetsSection: some View {
      VStack(alignment: .leading, spacing: CloveSpacing.medium) {
         Text("Quick Setup")
            .font(.system(.title3, design: .rounded).weight(.bold))
            .foregroundStyle(CloveColors.primaryText)
         
         VStack(spacing: CloveSpacing.small) {
            ComplexityPresetCard(
               title: "Simple",
               description: "Basic charts only",
               icon: "chart.line.uptrend.xyaxis",
               isSelected: isSimpleMode,
               onTap: setSimpleMode
            )
            
            ComplexityPresetCard(
               title: "Balanced",
               description: "Charts with smart insights",
               icon: "chart.bar.doc.horizontal",
               isSelected: isBalancedMode,
               onTap: setBalancedMode
            )
            
            ComplexityPresetCard(
               title: "Advanced",
               description: "All features including correlations",
               icon: "brain.head.profile",
               isSelected: isAdvancedMode,
               onTap: setAdvancedMode
            )
         }
      }
      .padding(CloveSpacing.large)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.medium)
            .fill(CloveColors.card)
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
      )
   }
   
   // MARK: - Individual Toggles Section
   
   private var individualTogglesSection: some View {
      VStack(alignment: .leading, spacing: CloveSpacing.medium) {
         Text("Individual Features")
            .font(.system(.title3, design: .rounded).weight(.bold))
            .foregroundStyle(CloveColors.primaryText)
         
         VStack(spacing: CloveSpacing.small) {
            InsightToggleRow(
               title: "Overview Dashboard",
               description: "Quick summary cards of your key health metrics",
               icon: "square.grid.2x2",
               isEnabled: overviewDashboard,
               onToggle: { value in
                  overviewDashboard = value
               }
            )
            
            InsightToggleRow(
               title: "Metric Charts",
               description: "Interactive charts for exploring your data trends",
               icon: "chart.line.uptrend.xyaxis",
               isEnabled: metricCharts,
               onToggle: { value in
                  metricCharts = value
               }
            )
            
            InsightToggleRow(
               title: "Smart Insights",
               description: "AI-powered analysis and pattern recognition",
               icon: "brain.head.profile",
               isEnabled: smartInsights,
               onToggle: { value in
                  smartInsights = value
               }
            )
            
            InsightToggleRow(
               title: "Cross-Reference Analysis",
               description: "Advanced correlation analysis between metrics",
               icon: "chart.bar.xaxis",
               isEnabled: correlations,
               onToggle: { value in
                  correlations = value
               }
            )
         }
      }
      .padding(CloveSpacing.large)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.medium)
            .fill(CloveColors.card)
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
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
   }
   
   private func setBalancedMode() {
      overviewDashboard = true
      smartInsights = true
      metricCharts = true
      correlations = false
   }
   
   private func setAdvancedMode() {
      overviewDashboard = true
      smartInsights = true
      metricCharts = true
      correlations = true
   }
}

// MARK: - Supporting Views

struct ComplexityPresetCard: View {
   let title: String
   let description: String
   let icon: String
   let isSelected: Bool
   let onTap: () -> Void
   
   var body: some View {
      Button(action: onTap) {
         HStack(spacing: CloveSpacing.medium) {
            Image(systemName: icon)
               .font(.system(size: 20))
               .foregroundStyle(isSelected ? .white : Theme.shared.accent)
               .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
               Text(title)
                  .font(.system(.body, design: .rounded).weight(.semibold))
                  .foregroundStyle(isSelected ? .white : CloveColors.primaryText)
               
               Text(description)
                  .font(CloveFonts.small())
                  .foregroundStyle(isSelected ? .white.opacity(0.8) : CloveColors.secondaryText)
            }
            
            Spacer()
            
            if isSelected {
               Image(systemName: "checkmark.circle.fill")
                  .font(.system(size: 20))
                  .foregroundStyle(.white)
            }
         }
         .padding(CloveSpacing.large)
         .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
               .fill(isSelected ? Theme.shared.accent : CloveColors.background)
               .overlay(
                  RoundedRectangle(cornerRadius: CloveCorners.medium)
                     .stroke(Theme.shared.accent.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
               )
         )
      }
      .buttonStyle(PlainButtonStyle())
   }
}

struct InsightToggleRow: View {
   let title: String
   let description: String
   let icon: String
   let isEnabled: Bool
   let onToggle: (Bool) -> Void
   
   var body: some View {
      HStack(spacing: CloveSpacing.medium) {
         Image(systemName: icon)
            .font(.system(size: 20))
            .foregroundStyle(Theme.shared.accent)
            .frame(width: 28, height: 28)
         
         VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
            Text(title)
               .font(.system(.body, design: .rounded).weight(.semibold))
               .foregroundStyle(CloveColors.primaryText)
            
            Text(description)
               .font(CloveFonts.small())
               .foregroundStyle(CloveColors.secondaryText)
               .lineLimit(2)
         }
         
         Spacer()
         
         Toggle("", isOn: .init(
            get: { isEnabled },
            set: { onToggle($0) }
         ))
         .toggleStyle(SwitchToggleStyle(tint: Theme.shared.accent))
      }
      .padding(CloveSpacing.large)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.medium)
            .fill(CloveColors.background)
            .overlay(
               RoundedRectangle(cornerRadius: CloveCorners.medium)
                  .stroke(Theme.shared.accent.opacity(0.1), lineWidth: 1)
            )
      )
   }
}

#Preview {
   NavigationView {
      InsightsCustomizationView()
   }
}
