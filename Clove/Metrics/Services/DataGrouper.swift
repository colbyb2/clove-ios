import Foundation


class DataGrouper {
    static let shared = DataGrouper()
    
    func getGroupedData(for data: [MetricDataPoint], metric: any MetricProvider, calendar: Calendar = .current) -> [GroupedDataPoint] {
        var counts: [ GroupKey : (count: Int, numericValue: Double) ] = [:]

        for point in data {
            let day = calendar.startOfDay(for: point.date)
            let key = GroupKey(date: day, value: metric.formatValue(point.value))
            if counts[key] == nil {
                counts[key] = (count: 1, numericValue: point.value)
            } else {
                counts[key]?.count += 1
            }
        }

        let finalData = counts.map { key, data in
            GroupedDataPoint(date: key.date, count: data.count, value: key.value, numericValue: data.numericValue)
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
    let numericValue: Double // Store the raw numeric value for color mapping
}
