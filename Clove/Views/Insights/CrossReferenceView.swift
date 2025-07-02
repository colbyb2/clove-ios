import SwiftUI
import Charts

// MARK: - Data Models

struct CorrelationAnalysis: Identifiable {
   let id = UUID()
   let primaryMetric: SelectableMetric
   let secondaryMetric: SelectableMetric
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
   let primary: SelectableMetric
   let secondary: SelectableMetric
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

enum CorrelationError: Error {
   case insufficientData
   case calculationError
   
   var localizedDescription: String {
      switch self {
      case .insufficientData:
         return "Not enough matching data points to calculate correlation"
      case .calculationError:
         return "Error calculating correlation coefficient"
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
         MetricSelectorView(
            selectedMetric: selectingPrimaryMetric ? viewModel.primaryMetric : viewModel.secondaryMetric
         ) { metric in
            handleMetricSelection(metric)
         }
      }
      .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
         Button("OK") {
            viewModel.errorMessage = nil
         }
      } message: {
         if let error = viewModel.errorMessage {
            Text(error)
         }
      }
   }
   
   // MARK: - Analysis Section
   
   private var analysisContentSection: some View {
      Group {
         if let analysis = viewModel.currentAnalysis {
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
         Text("Saved Correlations")
            .font(.system(.title3, design: .rounded).weight(.bold))
            .foregroundStyle(CloveColors.primaryText)
         
         ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CloveSpacing.medium) {
               ForEach(viewModel.savedCorrelations) { pair in
                  SavedCorrelationCard(pair: pair) {
                     viewModel.loadSavedCorrelation(pair)
                  } onDelete: {
                     viewModel.removeSavedCorrelation(pair)
                  }
               }
            }
            .padding(.horizontal, CloveSpacing.medium)
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
   
   // MARK: - Loading Section
   
   private var loadingSection: some View {
      VStack(spacing: CloveSpacing.medium) {
         ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: CloveColors.accent))
            .scaleEffect(1.2)
         
         Text("Calculating correlation...")
            .font(CloveFonts.body())
            .foregroundStyle(CloveColors.secondaryText)
      }
      .frame(height: 200)
      .frame(maxWidth: .infinity)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.medium)
            .fill(CloveColors.card)
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
      )
   }
   
   // MARK: - Empty State Section
   
   private var emptyStateSection: some View {
      VStack(spacing: CloveSpacing.large) {
         Image(systemName: "chart.bar.xaxis")
            .font(.system(size: 48))
            .foregroundStyle(CloveColors.accent.opacity(0.6))
         
         VStack(spacing: CloveSpacing.small) {
            Text("Select Two Metrics")
               .font(.system(.title2, design: .rounded).weight(.bold))
               .foregroundStyle(CloveColors.primaryText)
            
            Text("Choose two metrics to analyze their correlation and discover patterns in your health data")
               .font(CloveFonts.body())
               .foregroundStyle(CloveColors.secondaryText)
               .multilineTextAlignment(.center)
         }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, CloveSpacing.xlarge)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.medium)
            .fill(CloveColors.card)
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
      )
   }
   
   // MARK: - Helpers
   
   private func performAnalysis() {
      if let primary = viewModel.primaryMetric,
         let secondary = viewModel.secondaryMetric {
         viewModel.calculateCorrelation(primary: primary, secondary: secondary)
      }
   }
   
   private func handleMetricSelection(_ metric: SelectableMetric) {
      if selectingPrimaryMetric {
         viewModel.primaryMetric = metric
      } else {
         viewModel.secondaryMetric = metric
      }
      
      if let primary = viewModel.primaryMetric,
         let secondary = viewModel.secondaryMetric {
         viewModel.calculateCorrelation(primary: primary, secondary: secondary)
      }
   }
}


// MARK: - Supporting Views

struct CrossReferenceHeaderView: View {
   let analysis: CorrelationAnalysis?
   
   var body: some View {
      VStack(alignment: .leading, spacing: CloveSpacing.medium) {
         HStack {
            Image(systemName: "chart.bar.xaxis")
               .font(.system(size: 24))
               .foregroundStyle(CloveColors.accent)
            
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
            HStack(spacing: CloveSpacing.small) {
               Image(systemName: "info.circle.fill")
                  .font(.system(size: 14))
                  .foregroundStyle(CloveColors.accent)
               
               Text("Analyzing \(analysis.dataPoints.count) matching data points")
                  .font(CloveFonts.small())
                  .foregroundStyle(CloveColors.secondaryText)
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
}


struct MetricSelectionCardView: View {
   @Binding var primaryMetric: SelectableMetric?
   @Binding var secondaryMetric: SelectableMetric?
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
               .foregroundStyle(CloveColors.accent)
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
            .fill(CloveColors.accent)
      )
   }
}


struct MetricPairSelector: View {
   let title: String
   let selectedMetric: SelectableMetric?
   let onTap: () -> Void
   
   var body: some View {
      VStack(alignment: .leading, spacing: CloveSpacing.small) {
         Text(selectedMetric == nil ? title : selectedMetric!.name)
            .font(CloveFonts.small())
            .foregroundStyle(CloveColors.secondaryText)
            .fontWeight(.medium)
         
         Button(action: onTap) {
            HStack(spacing: CloveSpacing.small) {
               if let metric = selectedMetric {
                  Text(metric.icon)
                     .font(.system(size: 20))
               } else {
                  Spacer()
                  
                  Image(systemName: "plus.circle.dashed")
                     .font(.system(size: 24))
                     .foregroundStyle(CloveColors.accent)
               }
               
               Spacer()
               
               Image(systemName: "chevron.right")
                  .font(.system(size: 12))
                  .foregroundStyle(CloveColors.secondaryText)
            }
            .padding(CloveSpacing.medium)
            .background(
               RoundedRectangle(cornerRadius: CloveCorners.medium)
                  .fill(selectedMetric != nil ? CloveColors.accent.opacity(0.1) : CloveColors.background)
                  .overlay(
                     RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(CloveColors.accent.opacity(0.3), lineWidth: 1)
                  )
            )
         }
         .buttonStyle(PlainButtonStyle())
      }
   }
}

struct SavedCorrelationCard: View {
   let pair: MetricPair
   let onTap: () -> Void
   let onDelete: () -> Void
   
   var body: some View {
      VStack(alignment: .leading, spacing: CloveSpacing.small) {
         HStack {
            VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
               Text(pair.primary.name)
                  .font(CloveFonts.small())
                  .foregroundStyle(CloveColors.primaryText)
                  .fontWeight(.medium)
                  .lineLimit(1)
               
               Text("vs")
                  .font(CloveFonts.small())
                  .foregroundStyle(CloveColors.secondaryText)
               
               Text(pair.secondary.name)
                  .font(CloveFonts.small())
                  .foregroundStyle(CloveColors.primaryText)
                  .fontWeight(.medium)
                  .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: onDelete) {
               Image(systemName: "xmark.circle.fill")
                  .font(.system(size: 16))
                  .foregroundStyle(CloveColors.secondaryText)
            }
            .buttonStyle(PlainButtonStyle())
         }
         
         Button(action: onTap) {
            Text("Load Analysis")
               .font(CloveFonts.small())
               .foregroundStyle(CloveColors.accent)
               .fontWeight(.semibold)
         }
         .buttonStyle(PlainButtonStyle())
      }
      .padding(CloveSpacing.medium)
      .frame(width: 150)
      .background(
         RoundedRectangle(cornerRadius: CloveCorners.medium)
            .fill(CloveColors.background)
            .overlay(
               RoundedRectangle(cornerRadius: CloveCorners.medium)
                  .stroke(CloveColors.accent.opacity(0.2), lineWidth: 1)
            )
      )
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
               .foregroundStyle(CloveColors.accent)
               .frame(width: 24)
            
            VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
               Text("\(pair.primary.name) vs \(pair.secondary.name)")
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
                     .stroke(CloveColors.accent.opacity(0.1), lineWidth: 1)
               )
         )
      }
      .buttonStyle(PlainButtonStyle())
   }
}

#Preview {
   CrossReferenceView()
}
