import Foundation


class DataGrouper {
    static let shared = DataGrouper()
    
    func getGroupedData(for data: [MetricDataPoint], metric: any MetricProvider, calendar: Calendar = .current) -> [GroupedDataPoint] {
        var counts: [ GroupKey : Int ] = [:]
        
        for point in data {
            let day = calendar.startOfDay(for: point.date)
            let key = GroupKey(date: day, value: metric.formatValue(point.value))
            counts[key, default: 0] += 1
        }
        
        let finalData = counts.map { key, c in
            GroupedDataPoint(date: key.date, count: c, value: key.value)
        }
        .sorted { a, b in
            if a.date != b.date { return a.date < b.date }
            return a.value < b.value
        }
        
        return finalData
    }
}

struct GroupKey: Hashable {
    let date: Date
    let value: String
}

struct GroupedDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
    let value: String
}
