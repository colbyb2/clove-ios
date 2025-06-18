import Foundation
import GRDB

@Observable
class InsightsViewModel {
    var logs: [DailyLog] = []
    var flareCount: Int = 0

    func loadLogs() {
        self.logs = LogsRepo.shared.getLogs()
        self.flareCount = self.logs.filter { $0.isFlareDay }.count
    }
}
