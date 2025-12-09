import SwiftUI
import Charts

// MARK: - Data Models

struct CorrelationAnalysis: Identifiable {
   let id = UUID()
   let primaryMetric: any MetricProvider
   let secondaryMetric: any MetricProvider
   let coefficient: Double
   let significance: Double
   let pValue: Double
   let dataPoints: [(Date, Double, Double)]
   let timeRange: DateInterval
   let strengthDescription: String
   let insights: [String]
   
   var isSignificant: Bool {
      pValue < 0.05
   }
   
   var correlationStrength: String {
      let absCoeff = abs(coefficient)
      switch absCoeff {
      case 0.8...1.0: return "Very Strong"
      case 0.6..<0.8: return "Strong"
      case 0.4..<0.6: return "Moderate"
      case 0.2..<0.4: return "Weak"
      default: return "Very Weak"
      }
   }
   
   var correlationDirection: String {
      if coefficient > 0 {
         return "Positive"
      } else if coefficient < 0 {
         return "Negative"
      } else {
         return "No"
      }
   }
}

struct MetricPair: Identifiable, Hashable {
   let id = UUID()
   let primary: any MetricProvider
   let secondary: any MetricProvider
   let correlationStrength: Double
   let lastAnalyzed: Date
   
   func hash(into hasher: inout Hasher) {
      hasher.combine(primary.id)
      hasher.combine(secondary.id)
   }
   
   static func == (lhs: MetricPair, rhs: MetricPair) -> Bool {
      lhs.primary.id == rhs.primary.id && lhs.secondary.id == rhs.secondary.id
   }
}

enum CorrelationError: Error, LocalizedError {
   case insufficientData
   case calculationError

   var errorDescription: String? {
      switch self {
      case .insufficientData:
         return "Not enough matching data points to calculate correlation. You need at least 3 days where both metrics were tracked."
      case .calculationError:
         return "Unable to calculate correlation coefficient. Please try different metrics."
      }
   }
}

// MARK: - CrossReference View

struct CrossReferenceView: View {
   @State private var viewModel = CrossReferenceViewModel()
   @State private var showingMetricSelector = false
   @State private var selectingPrimaryMetric = true
   
   var body: some View {
      NavigationView {
         ScrollView {
            VStack(spacing: CloveSpacing.large) {
               CrossReferenceHeaderView(analysis: viewModel.currentAnalysis)
               
               MetricSelectionCardView(
                  primaryMetric: $viewModel.primaryMetric,
                  secondaryMetric: $viewModel.secondaryMetric,
                  onSelectPrimary: {
                     selectingPrimaryMetric = true
                     showingMetricSelector = true
                  },
                  onSelectSecondary: {
                     selectingPrimaryMetric = false
                     showingMetricSelector = true
                  },
                  onAnalyze: performAnalysis
               )
               
               analysisContentSection
               
               if !viewModel.savedCorrelations.isEmpty {
                  savedCorrelationsSection
               }
               
               if !viewModel.suggestedPairs.isEmpty {
                  suggestedCorrelationsSection
               }
            }
            .padding(.horizontal, CloveSpacing.large)
            .padding(.bottom, CloveSpacing.xlarge)
         }
         .background(CloveColors.background.ignoresSafeArea())
         .navigationTitle("Cross-Reference")
         .navigationBarTitleDisplayMode(.large)
      }
      .sheet(isPresented: $showingMetricSelector) {
         MetricExplorer { metricId in
            Task {
               await viewModel.selectMetric(id: metricId, isPrimary: selectingPrimaryMetric)
            }
         }
         .presentationDragIndicator(.visible)
      }
   }
   
   // MARK: - Analysis Section
   
   private var analysisContentSection: some View {
      Group {
         if let errorMessage = viewModel.errorMessage {
            errorMessageSection(errorMessage)
         } else if let analysis = viewModel.currentAnalysis {
            AnalysisResultsView(analysis: analysis) {
               viewModel.saveCorrelation(analysis)
            }
         } else if viewModel.isCalculating {
            loadingSection
         } else {
            emptyStateSection
         }
      }
   }
   
   // MARK: - Saved Correlations Section
   
   private var savedCorrelationsSection: some View {
      VStack(alignment: .leading, spacing: CloveSpacing.medium) {
         HStack {
            Text("Saved Correlations")
               .font(.system(.title3, design: .rounded).weight(.bold))
               .foregroundStyle(CloveColors.primaryText)

            Spacer()

            Text("\(viewModel.savedCorrelations.count)")
               .font(CloveFonts.small())
               .foregroundStyle(CloveColors.secondaryText)
               .fontWeight(.semibold)
               .padding(.horizontal, CloveSpacing.small)
               .padding(.vertical, CloveSpacing.xsmall)
               .background(
                  RoundedRectangle(cornerRadius: CloveCorners.full)
                     .fill(Theme.shared.accent.opacity(0.1))
               )
         }

         let columns = [
            GridItem(.flexible(), spacing: CloveSpacing.medium),
            GridItem(.flexible(), spacing: CloveSpacing.medium)
         ]

         LazyVGrid(columns: columns, spacing: CloveSpacing.medium) {
            ForEach(viewModel.savedCorrelations) { pair in
               SavedCorrelationCard(pair: pair) {
                  viewModel.loadSavedCorrelation(pair)
               } onDelete: {
                  viewModel.removeSavedCorrelation(pair)
               }
            }
         }
      }
      .padding(CloveSpacing.large)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.medium)
            .fill(CloveColors.card)
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
      )
   }
   
   // MARK: - Suggested Correlations Section
   
   private var suggestedCorrelationsSection: some View {
      VStack(alignment: .leading, spacing: CloveSpacing.medium) {
         Text("Suggested Correlations")
            .font(.system(.title3, design: .rounded).weight(.bold))
            .foregroundStyle(CloveColors.primaryText)
         
         VStack(spacing: CloveSpacing.small) {
            ForEach(viewModel.suggestedPairs.prefix(3)) { pair in
               SuggestedCorrelationRow(pair: pair) {
                  viewModel.calculateCorrelation(primary: pair.primary, secondary: pair.secondary)
               }
            }
         }
      }
      .padding(CloveSpacing.large)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.medium)
            .fill(CloveColors.card)
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
      )
   }
   
   // MARK: - Error Section

   private func errorMessageSection(_ errorMessage: String) -> some View {
      VStack(alignment: .leading, spacing: CloveSpacing.medium) {
         HStack(alignment: .top, spacing: CloveSpacing.medium) {
            Image(systemName: "exclamationmark.triangle.fill")
               .font(.system(size: 32))
               .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: CloveSpacing.small) {
               Text("Analysis Error")
                  .font(.system(.title3, design: .rounded).weight(.bold))
                  .foregroundStyle(CloveColors.primaryText)

               Text(errorMessage)
                  .font(CloveFonts.body())
                  .foregroundStyle(CloveColors.secondaryText)
                  .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button(action: {
               viewModel.errorMessage = nil
            }) {
               Image(systemName: "xmark.circle.fill")
                  .font(.system(size: 20))
                  .foregroundStyle(CloveColors.secondaryText)
            }
            .buttonStyle(PlainButtonStyle())
         }

         // Suggestions based on error type
         if errorMessage.contains("insufficient") || errorMessage.contains("Not enough") {
            Divider()

            VStack(alignment: .leading, spacing: CloveSpacing.small) {
               HStack(spacing: CloveSpacing.xsmall) {
                  Image(systemName: "lightbulb.fill")
                     .font(.system(size: 14))
                     .foregroundStyle(Theme.shared.accent)
                  Text("Suggestions")
                     .font(CloveFonts.body())
                     .foregroundStyle(CloveColors.primaryText)
                     .fontWeight(.semibold)
               }

               VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
                  suggestionRow(text: "Try selecting metrics you've tracked more frequently")
                  suggestionRow(text: "Ensure both metrics have overlapping dates")
                  suggestionRow(text: "Track more data over time for better analysis")
               }
            }
         }

         // Retry button
         HStack {
            Spacer()
            Button(action: {
               viewModel.errorMessage = nil
               if let primary = viewModel.primaryMetric,
                  let secondary = viewModel.secondaryMetric {
                  viewModel.calculateCorrelation(primary: primary, secondary: secondary)
               }
            }) {
               HStack(spacing: CloveSpacing.small) {
                  Image(systemName: "arrow.clockwise")
                     .font(.system(size: 14))
                  Text("Try Again")
                     .font(CloveFonts.body())
                     .fontWeight(.semibold)
               }
               .foregroundStyle(.white)
               .padding(.horizontal, CloveSpacing.medium)
               .padding(.vertical, CloveSpacing.small)
               .background(
                  RoundedRectangle(cornerRadius: CloveCorners.medium)
                     .fill(Theme.shared.accent)
               )
            }
            .buttonStyle(PlainButtonStyle())
            Spacer()
         }
      }
      .padding(CloveSpacing.large)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.medium)
            .fill(CloveColors.card)
            .overlay(
               RoundedRectangle(cornerRadius: CloveCorners.medium)
                  .stroke(.orange.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
      )
   }

   private func suggestionRow(text: String) -> some View {
      HStack(alignment: .top, spacing: CloveSpacing.xsmall) {
         Text("•")
            .font(CloveFonts.small())
            .foregroundStyle(CloveColors.secondaryText)
         Text(text)
            .font(CloveFonts.small())
            .foregroundStyle(CloveColors.secondaryText)
      }
   }

   // MARK: - Loading Section

   private var loadingSection: some View {
      VStack(spacing: CloveSpacing.large) {
         ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: Theme.shared.accent))
            .scaleEffect(1.5)

         VStack(spacing: CloveSpacing.small) {
            Text("Analyzing Correlation")
               .font(.system(.title3, design: .rounded).weight(.bold))
               .foregroundStyle(CloveColors.primaryText)

            if let step = viewModel.calculationStep {
               Text(step)
                  .font(CloveFonts.body())
                  .foregroundStyle(CloveColors.secondaryText)
                  .multilineTextAlignment(.center)
            }
         }

         // Progress steps indicator
         HStack(spacing: CloveSpacing.small) {
            ForEach(0..<4, id: \.self) { index in
               Circle()
                  .fill(stepIndicatorColor(for: index))
                  .frame(width: 8, height: 8)
            }
         }
      }
      .padding(.vertical, CloveSpacing.xlarge)
      .frame(maxWidth: .infinity)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.medium)
            .fill(CloveColors.card)
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
      )
   }

   private func stepIndicatorColor(for index: Int) -> Color {
      let currentStep = viewModel.currentCalculationStepIndex
      if index < currentStep {
         return CloveColors.green // Completed
      } else if index == currentStep {
         return Theme.shared.accent // Current
      } else {
         return CloveColors.secondaryText.opacity(0.2) // Not started
      }
   }
   
   // MARK: - Empty State Section
   
   private var emptyStateSection: some View {
      VStack(alignment: .leading, spacing: CloveSpacing.large) {
         // Header
         VStack(spacing: CloveSpacing.medium) {
            Image(systemName: "chart.bar.xaxis")
               .font(.system(size: 48))
               .foregroundStyle(Theme.shared.accent.opacity(0.6))

            VStack(spacing: CloveSpacing.small) {
               Text("Discover Health Patterns")
                  .font(.system(.title2, design: .rounded).weight(.bold))
                  .foregroundStyle(CloveColors.primaryText)

               Text("Correlation analysis helps you understand how different aspects of your health relate to each other")
                  .font(CloveFonts.body())
                  .foregroundStyle(CloveColors.secondaryText)
                  .multilineTextAlignment(.center)
            }
         }
         .frame(maxWidth: .infinity)

         Divider()

         // Educational content
         VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            Text("What You Can Learn")
               .font(.system(.body, design: .rounded).weight(.semibold))
               .foregroundStyle(CloveColors.primaryText)

            VStack(alignment: .leading, spacing: CloveSpacing.small) {
               educationalRow(
                  icon: "arrow.up.right",
                  iconColor: CloveColors.green,
                  title: "Positive Patterns",
                  description: "Find metrics that increase or decrease together"
               )

               educationalRow(
                  icon: "arrow.down.right",
                  iconColor: .orange,
                  title: "Inverse Patterns",
                  description: "Discover when one metric goes up while another goes down"
               )

               educationalRow(
                  icon: "lightbulb.fill",
                  iconColor: Theme.shared.accent,
                  title: "Actionable Insights",
                  description: "Understand which habits impact your wellbeing most"
               )
            }
         }

         Divider()

         // Example correlations
         VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            Text("Common Examples")
               .font(.system(.body, design: .rounded).weight(.semibold))
               .foregroundStyle(CloveColors.primaryText)

            VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
               exampleRow(primary: "😊 Mood", secondary: "⚡️ Energy Level")
               exampleRow(primary: "💊 Medication", secondary: "😌 Pain Level")
               exampleRow(primary: "💧 Hydration", secondary: "🤕 Headaches")
            }
         }

         // Call to action
         VStack(spacing: CloveSpacing.small) {
            Text("Get Started")
               .font(.system(.body, design: .rounded).weight(.semibold))
               .foregroundStyle(CloveColors.primaryText)

            Text("Tap the metric selector cards above to choose two metrics and analyze their relationship")
               .font(CloveFonts.small())
               .foregroundStyle(CloveColors.secondaryText)
               .multilineTextAlignment(.center)
         }
         .frame(maxWidth: .infinity)
         .padding(.top, CloveSpacing.small)
      }
      .padding(CloveSpacing.large)
      .frame(maxWidth: .infinity)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.medium)
            .fill(CloveColors.card)
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
      )
   }

   private func educationalRow(icon: String, iconColor: Color, title: String, description: String) -> some View {
      HStack(alignment: .top, spacing: CloveSpacing.small) {
         Image(systemName: icon)
            .font(.system(size: 16))
            .foregroundStyle(iconColor)
            .frame(width: 24)

         VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
            Text(title)
               .font(CloveFonts.body())
               .foregroundStyle(CloveColors.primaryText)
               .fontWeight(.medium)

            Text(description)
               .font(CloveFonts.small())
               .foregroundStyle(CloveColors.secondaryText)
         }
      }
   }

   private func exampleRow(primary: String, secondary: String) -> some View {
      HStack(spacing: CloveSpacing.small) {
         Image(systemName: "arrow.right")
            .font(.system(size: 10))
            .foregroundStyle(CloveColors.secondaryText)

         Text("\(primary)")
            .font(CloveFonts.small())
            .foregroundStyle(CloveColors.primaryText)

         Image(systemName: "arrow.left.and.right")
            .font(.system(size: 10))
            .foregroundStyle(Theme.shared.accent)

         Text("\(secondary)")
            .font(CloveFonts.small())
            .foregroundStyle(CloveColors.primaryText)
      }
      .padding(.vertical, CloveSpacing.xsmall)
      .padding(.horizontal, CloveSpacing.small)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.small)
            .fill(Theme.shared.accent.opacity(0.05))
      )
   }
   
   // MARK: - Helpers
   
   private func performAnalysis() {
      if let primary = viewModel.primaryMetric,
         let secondary = viewModel.secondaryMetric {
         viewModel.calculateCorrelation(primary: primary, secondary: secondary)
      }
   }
   
//   private func handleMetricSelection(_ metric: SelectableMetric) {
//      if selectingPrimaryMetric {
//         viewModel.primaryMetric = metric
//      } else {
//         viewModel.secondaryMetric = metric
//      }
//      
//      if let primary = viewModel.primaryMetric,
//         let secondary = viewModel.secondaryMetric {
//         viewModel.calculateCorrelation(primary: primary, secondary: secondary)
//      }
//   }
}


// MARK: - Supporting Views

struct CrossReferenceHeaderView: View {
   let analysis: CorrelationAnalysis?

   var body: some View {
      VStack(alignment: .leading, spacing: CloveSpacing.medium) {
         HStack {
            Image(systemName: "chart.bar.xaxis")
               .font(.system(size: 24))
               .foregroundStyle(Theme.shared.accent)

            VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
               Text("Correlation Analysis")
                  .font(.system(.title2, design: .rounded).weight(.bold))
                  .foregroundStyle(CloveColors.primaryText)

               Text("Discover relationships between your health metrics")
                  .font(CloveFonts.small())
                  .foregroundStyle(CloveColors.secondaryText)
            }

            Spacer()
         }

         if let analysis {
            HStack(spacing: CloveSpacing.medium) {
               HStack(spacing: CloveSpacing.small) {
                  Image(systemName: "info.circle.fill")
                     .font(.system(size: 14))
                     .foregroundStyle(Theme.shared.accent)

                  Text("Analyzing \(analysis.dataPoints.count) matching data points")
                     .font(CloveFonts.small())
                     .foregroundStyle(CloveColors.secondaryText)
               }

               Spacer()

               strengthBadge(for: analysis)
            }
         }
      }
      .padding(CloveSpacing.large)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.medium)
            .fill(CloveColors.card)
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
      )
   }

   private func strengthBadge(for analysis: CorrelationAnalysis) -> some View {
      let absCoeff = abs(analysis.coefficient)
      let strengthColor: Color = {
         switch absCoeff {
         case 0.6...: return CloveColors.green
         case 0.4..<0.6: return Theme.shared.accent
         case 0.2..<0.4: return .orange
         default: return CloveColors.secondaryText
         }
      }()

      let strengthLabel: String = {
         switch absCoeff {
         case 0.8...1.0: return "Very Strong"
         case 0.6..<0.8: return "Strong"
         case 0.4..<0.6: return "Moderate"
         case 0.2..<0.4: return "Weak"
         default: return "Very Weak"
         }
      }()

      return VStack(spacing: CloveSpacing.xsmall) {
         Text(strengthLabel)
            .font(CloveFonts.small())
            .foregroundStyle(strengthColor)
            .fontWeight(.bold)

         // Strength meter bars
         HStack(spacing: 1) {
            let maxBars = 5
            let filledBars = max(1, Int(absCoeff * Double(maxBars)))

            ForEach(0..<maxBars, id: \.self) { index in
               RoundedRectangle(cornerRadius: 1)
                  .fill(index < filledBars ? strengthColor : strengthColor.opacity(0.2))
                  .frame(width: 6, height: 14)
            }
         }
      }
      .padding(.horizontal, CloveSpacing.small)
      .padding(.vertical, CloveSpacing.small)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.small)
            .fill(strengthColor.opacity(0.15))
      )
   }
}


struct MetricSelectionCardView: View {
   @Binding var primaryMetric: (any MetricProvider)?
   @Binding var secondaryMetric: (any MetricProvider)?
   let onSelectPrimary: () -> Void
   let onSelectSecondary: () -> Void
   let onAnalyze: () -> Void
   
   var body: some View {
      VStack(spacing: CloveSpacing.medium) {
         HStack {
            Text("Select Metrics")
               .font(.system(.title3, design: .rounded).weight(.bold))
               .foregroundStyle(CloveColors.primaryText)
            
            Spacer()
            
            if primaryMetric != nil && secondaryMetric != nil {
               analyzeButton
            }
         }
         
         HStack(spacing: CloveSpacing.medium) {
            MetricPairSelector(
               title: "Primary Metric",
               selectedMetric: primaryMetric,
               onTap: onSelectPrimary
            )
            
            Image(systemName: "arrow.left.and.right")
               .font(.system(size: 20))
               .foregroundStyle(Theme.shared.accent)
               .frame(width: 30)
            
            MetricPairSelector(
               title: "Compare With",
               selectedMetric: secondaryMetric,
               onTap: onSelectSecondary
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
   
   private var analyzeButton: some View {
      Button("Analyze") {
         onAnalyze()
      }
      .font(CloveFonts.small())
      .foregroundStyle(.white)
      .fontWeight(.semibold)
      .padding(.horizontal, CloveSpacing.medium)
      .padding(.vertical, CloveSpacing.small)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.full)
            .fill(Theme.shared.accent)
      )
   }
}


struct MetricPairSelector: View {
   let title: String
   let selectedMetric: (any MetricProvider)?
   let onTap: () -> Void
   @State private var recentDataPoints: [MetricDataPoint] = []

   var body: some View {
      VStack(alignment: .leading, spacing: CloveSpacing.small) {
         Text(selectedMetric == nil ? title : selectedMetric!.displayName)
            .font(CloveFonts.small())
            .foregroundStyle(CloveColors.secondaryText)
            .fontWeight(.medium)

         Button(action: onTap) {
            VStack(spacing: CloveSpacing.small) {
               HStack(spacing: CloveSpacing.small) {
                  if let metric = selectedMetric {
                     Text(metric.icon)
                        .font(.system(size: 20))
                  } else {
                     Spacer()

                     Image(systemName: "plus.circle.dashed")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.shared.accent)
                  }

                  Spacer()

                  Image(systemName: "chevron.right")
                     .font(.system(size: 12))
                     .foregroundStyle(CloveColors.secondaryText)
               }

               // Mini preview chart
               if let metric = selectedMetric, !recentDataPoints.isEmpty {
                  Chart {
                     ForEach(Array(recentDataPoints.enumerated()), id: \.offset) { index, point in
                        LineMark(
                           x: .value("Date", point.date),
                           y: .value("Value", point.value)
                        )
                        .foregroundStyle(Theme.shared.accent.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .interpolationMethod(.catmullRom)
                     }
                  }
                  .frame(height: 40)
                  .chartXAxis(.hidden)
                  .chartYAxis(.hidden)
                  .chartYScale(domain: chartYDomain)
               }
            }
            .padding(CloveSpacing.medium)
            .background(
               RoundedRectangle(cornerRadius: CloveCorners.medium)
                  .fill(selectedMetric != nil ? Theme.shared.accent.opacity(0.1) : CloveColors.background)
                  .overlay(
                     RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(Theme.shared.accent.opacity(0.3), lineWidth: 1)
                  )
            )
         }
         .buttonStyle(PlainButtonStyle())
      }
      .task(id: selectedMetric?.id) {
         await loadRecentData()
      }
   }

   private var chartYDomain: ClosedRange<Double> {
      guard !recentDataPoints.isEmpty else { return 0...1 }
      let values = recentDataPoints.map { $0.value }
      guard let min = values.min(), let max = values.max(), max != min else {
         return 0...10
      }
      let padding = (max - min) * 0.2
      return (min - padding)...(max + padding)
   }

   private func loadRecentData() async {
      guard let metric = selectedMetric else {
         recentDataPoints = []
         return
      }

      // Get last 30 days of data using TimePeriod
      let dataPoints = await metric.getDataPoints(for: .month)

      await MainActor.run {
         // Take last 14 points for the preview
         self.recentDataPoints = Array(dataPoints.suffix(14))
      }
   }
}

struct SavedCorrelationCard: View {
   let pair: MetricPair
   let onTap: () -> Void
   let onDelete: () -> Void

   var body: some View {
      VStack(alignment: .leading, spacing: CloveSpacing.small) {
         HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
               HStack(spacing: CloveSpacing.xsmall) {
                  Text(pair.primary.icon)
                     .font(.system(size: 14))
                  Text(pair.primary.displayName)
                     .font(CloveFonts.small())
                     .foregroundStyle(CloveColors.primaryText)
                     .fontWeight(.medium)
                     .lineLimit(1)
               }

               HStack(spacing: CloveSpacing.xsmall) {
                  Image(systemName: "arrow.left.and.right")
                     .font(.system(size: 10))
                     .foregroundStyle(CloveColors.secondaryText)
                  Text("vs")
                     .font(CloveFonts.small())
                     .foregroundStyle(CloveColors.secondaryText)
               }

               HStack(spacing: CloveSpacing.xsmall) {
                  Text(pair.secondary.icon)
                     .font(.system(size: 14))
                  Text(pair.secondary.displayName)
                     .font(CloveFonts.small())
                     .foregroundStyle(CloveColors.primaryText)
                     .fontWeight(.medium)
                     .lineLimit(1)
               }
            }

            Spacer()

            Button(action: onDelete) {
               Image(systemName: "xmark.circle.fill")
                  .font(.system(size: 18))
                  .foregroundStyle(CloveColors.secondaryText)
            }
            .buttonStyle(PlainButtonStyle())
         }

         // Correlation strength badge
         HStack(spacing: CloveSpacing.xsmall) {
            strengthIndicator
            Text(strengthLabel)
               .font(CloveFonts.small())
               .foregroundStyle(strengthColor)
               .fontWeight(.semibold)
         }
         .padding(.horizontal, CloveSpacing.small)
         .padding(.vertical, CloveSpacing.xsmall)
         .background(
            RoundedRectangle(cornerRadius: CloveCorners.small)
               .fill(strengthColor.opacity(0.15))
         )

         Button(action: onTap) {
            HStack {
               Text("Load")
                  .font(CloveFonts.small())
                  .fontWeight(.semibold)
               Image(systemName: "arrow.right.circle.fill")
                  .font(.system(size: 12))
            }
            .foregroundStyle(Theme.shared.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, CloveSpacing.xsmall)
            .background(
               RoundedRectangle(cornerRadius: CloveCorners.small)
                  .fill(Theme.shared.accent.opacity(0.1))
            )
         }
         .buttonStyle(PlainButtonStyle())
      }
      .padding(CloveSpacing.medium)
      .frame(maxWidth: .infinity)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.medium)
            .fill(CloveColors.background)
            .overlay(
               RoundedRectangle(cornerRadius: CloveCorners.medium)
                  .stroke(strengthColor.opacity(0.3), lineWidth: 1.5)
            )
      )
   }

   private var strengthIndicator: some View {
      let absCoeff = abs(pair.correlationStrength)
      let maxBars = 5
      let filledBars = max(1, Int(absCoeff * Double(maxBars)))

      return HStack(spacing: 1) {
         ForEach(0..<maxBars, id: \.self) { index in
            RoundedRectangle(cornerRadius: 1)
               .fill(index < filledBars ? strengthColor : strengthColor.opacity(0.2))
               .frame(width: 4, height: 12)
         }
      }
   }

   private var strengthLabel: String {
      let absCoeff = abs(pair.correlationStrength)
      switch absCoeff {
      case 0.8...1.0: return "Very Strong"
      case 0.6..<0.8: return "Strong"
      case 0.4..<0.6: return "Moderate"
      case 0.2..<0.4: return "Weak"
      default: return "Very Weak"
      }
   }

   private var strengthColor: Color {
      let absCoeff = abs(pair.correlationStrength)
      switch absCoeff {
      case 0.6...: return CloveColors.green
      case 0.4..<0.6: return Theme.shared.accent
      case 0.2..<0.4: return .orange
      default: return CloveColors.secondaryText
      }
   }
}

struct SuggestedCorrelationRow: View {
   let pair: MetricPair
   let onTap: () -> Void
   
   var body: some View {
      Button(action: onTap) {
         HStack(spacing: CloveSpacing.medium) {
            Image(systemName: "lightbulb")
               .font(.system(size: 20))
               .foregroundStyle(Theme.shared.accent)
               .frame(width: 24)
            
            VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
               Text("\(pair.primary.displayName) vs \(pair.secondary.displayName)")
                  .font(CloveFonts.body())
                  .foregroundStyle(CloveColors.primaryText)
                  .fontWeight(.medium)
               
               Text("Common correlation pattern")
                  .font(CloveFonts.small())
                  .foregroundStyle(CloveColors.secondaryText)
            }
            
            Spacer()
            
            Image(systemName: "arrow.right")
               .font(.system(size: 12))
               .foregroundStyle(CloveColors.secondaryText)
         }
         .padding(CloveSpacing.medium)
         .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
               .fill(CloveColors.background)
               .overlay(
                  RoundedRectangle(cornerRadius: CloveCorners.medium)
                     .stroke(Theme.shared.accent.opacity(0.1), lineWidth: 1)
               )
         )
      }
      .buttonStyle(PlainButtonStyle())
   }
}

#Preview {
   CrossReferenceView()
}
