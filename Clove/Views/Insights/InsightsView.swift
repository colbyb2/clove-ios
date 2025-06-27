import SwiftUI

struct InsightsView: View {
   @State private var viewModel = InsightsViewModel()
   
   var body: some View {
      ScrollView {
         VStack(spacing: 24) {
            if (!viewModel.logs.isEmpty) {
               MoodGraphView(logs: viewModel.logs)
               PainEnergyGraphView(logs: viewModel.logs)
               
               SymptomSummaryView(logs: viewModel.logs)
            }

            if viewModel.flareCount > 0 {
               Text("Flare-ups this month: \(viewModel.flareCount)")
                  .font(.headline)
            }
         }
         .padding()
      }
      .scrollIndicators(.hidden)
      .navigationTitle("Insights")
      .onAppear {
         viewModel.loadLogs()
      }
   }
}
