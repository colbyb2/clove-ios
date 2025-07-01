import Foundation
import GRDB

@Observable
class InsightsViewModel {
    // MARK: - Legacy Properties (maintain backward compatibility)
    var logs: [DailyLog] = []
    var flareCount: Int = 0
    
    // MARK: - New Foundation Properties
    var chartDataManager = ChartDataManager.shared
    var timePeriodManager = TimePeriodManager.shared
    var selectedMetricData: [ChartDataPoint] = []
    var selectedSymptomData: [SymptomDataPoint] = []
    var isLoadingChartData = false
    var selectedMetricForChart: SelectableMetric?
    
    // MARK: - Existing Method (maintain backward compatibility)
    func loadLogs() {
        self.logs = LogsRepo.shared.getLogs()
        self.flareCount = self.logs.filter { $0.isFlareDay }.count
    }
    
    // MARK: - New Foundation Methods
    func loadFoundationData() {
        loadLogs() // Maintain existing functionality
        loadSelectedMetricData()
    }
    
    func loadSelectedMetricData() {
        guard let metric = selectedMetricForChart else { return }
        
        isLoadingChartData = true
        
        Task { @MainActor in
            do {
                if let metricType = metric.type {
                    // Core health metric
                    let data = chartDataManager.getChartData(
                        for: metricType,
                        period: timePeriodManager.selectedPeriod
                    )
                    self.selectedMetricData = data
                    self.selectedSymptomData = []
                } else if let symptomName = metric.symptomName {
                    // Symptom metric
                    let data = chartDataManager.getSymptomChartData(
                        symptomName: symptomName,
                        period: timePeriodManager.selectedPeriod
                    )
                    self.selectedSymptomData = data
                    self.selectedMetricData = []
                }
                
                self.isLoadingChartData = false
            }
        }
    }
    
    func selectMetricForChart(_ metric: SelectableMetric) {
        selectedMetricForChart = metric
        loadSelectedMetricData()
    }
    
    func refreshCurrentMetricData() {
        loadSelectedMetricData()
    }
    
    // MARK: - Helper Methods
    func getCurrentChartDataForUniversalChart() -> [ChartDataPoint] {
        if !selectedMetricData.isEmpty {
            return selectedMetricData
        } else if !selectedSymptomData.isEmpty {
            // Convert symptom data to chart data format
            return selectedSymptomData.map { symptomPoint in
                ChartDataPoint(
                    date: symptomPoint.date,
                    value: symptomPoint.value,
                    metricType: .mood, // Placeholder - symptoms don't have MetricType
                    metricName: symptomPoint.symptomName,
                    category: .symptoms
                )
            }
        }
        return []
    }
    
    func getCurrentMetricName() -> String {
        return selectedMetricForChart?.name ?? "Select a metric"
    }
    
    func getCurrentTimeRangeText() -> String {
        return timePeriodManager.currentPeriodShortText
    }
}
