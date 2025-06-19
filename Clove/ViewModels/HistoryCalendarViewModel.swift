import Foundation
import GRDB

@Observable
class HistoryCalendarViewModel {
   var logsByDate: [Date: DailyLog] = [:]
   var selectedDate: Date? = nil
   var colorMode: ColorMode = .Mood
   
   let calendar = Calendar.current
   
   var monthLogs: [DailyLog] {
      logsByDate.filter { calendar.isDate($0.key, equalTo: selectedDate ?? Date(), toGranularity: .month) }.map(\.value)
   }
   
   var averageMood: Int {
      let moods = monthLogs.compactMap { $0.mood }
      return moods.isEmpty ? 0 : moods.reduce(0, +) / moods.count
   }
   
   var averagePain: Int {
      let pains = monthLogs.compactMap { $0.painLevel }
      return pains.isEmpty ? 0 : pains.reduce(0, +) / pains.count
   }
   
   init() {
      loadLogs()
   }
   
   func loadLogs() {
      let logs = LogsRepo.shared.getLogs()
      self.logsByDate = Dictionary(uniqueKeysWithValues: logs.map { ($0.date.stripTime(), $0) })
   }
   
   func log(for date: Date) -> DailyLog? {
      logsByDate[date.stripTime()]
   }
}

enum ColorMode {
   case Mood
   case Pain
}
