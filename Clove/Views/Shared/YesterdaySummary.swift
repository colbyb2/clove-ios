import SwiftUI

struct YesterdaySummary: View {
    let yesterdayLog: DailyLog?
    let settings: UserSettings
    
    var body: some View {
        if let log = yesterdayLog {
            YesterdayDataView(log: log, settings: settings)
        } else {
            NoDataView()
        }
    }
}

// MARK: - Yesterday Data View
struct YesterdayDataView: View {
    let log: DailyLog
    let settings: UserSettings
    
    var body: some View {
        VStack(spacing: CloveSpacing.medium) {
            SummaryHeader(log: log)
            MetricsGrid(log: log, settings: settings)
            SymptomsSection(log: log, settings: settings)
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .stroke(CloveColors.background, lineWidth: 1)
        )
    }
}

// MARK: - Summary Header
struct SummaryHeader: View {
    let log: DailyLog
    
    var body: some View {
        HStack {
            HStack(spacing: CloveSpacing.small) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(CloveColors.secondaryText)
                
                Text("Yesterday's Summary")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(CloveColors.primaryText)
            }
            
            Spacer()
            
            if log.isFlareDay {
                FlareDayBadge()
            }
        }
    }
}

// MARK: - Flare Day Badge
struct FlareDayBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("🔥")
                .font(.system(size: 14))
            Text("Flare Day")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CloveColors.error)
        }
    }
}

// MARK: - Metrics Grid
struct MetricsGrid: View {
    let log: DailyLog
    let settings: UserSettings
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: CloveSpacing.medium) {
            
            if settings.trackMood, let mood = log.mood {
                MetricCard(
                    title: "Mood",
                    value: mood,
                    emoji: YesterdayHelpers.moodEmoji(for: mood),
                    color: YesterdayHelpers.moodColor(for: mood)
                )
            }
            
            if settings.trackPain, let pain = log.painLevel {
                MetricCard(
                    title: "Pain",
                    value: pain,
                    emoji: "🩹",
                    color: YesterdayHelpers.painColor(for: pain)
                )
            }
            
            if settings.trackEnergy, let energy = log.energyLevel {
                MetricCard(
                    title: "Energy",
                    value: energy,
                    emoji: "⚡",
                    color: YesterdayHelpers.energyColor(for: energy)
                )
            }
        }
    }
}

// MARK: - Symptoms Section
struct SymptomsSection: View {
    let log: DailyLog
    let settings: UserSettings
    
    private var notableSymptoms: [SymptomRating] {
        log.symptomRatings.filter { $0.rating >= 7 || $0.rating <= 3 }
    }
    
    var body: some View {
        if settings.trackSymptoms && !log.symptomRatings.isEmpty && !notableSymptoms.isEmpty {
            VStack(alignment: .leading, spacing: CloveSpacing.small) {
                Text("Notable Symptoms")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CloveColors.secondaryText)
                
                SymptomsGrid(symptoms: Array(notableSymptoms.prefix(4)))
            }
        }
    }
}

// MARK: - Symptoms Grid
struct SymptomsGrid: View {
    let symptoms: [SymptomRating]
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: CloveSpacing.small) {
            ForEach(symptoms, id: \.symptomId) { symptom in
                SymptomRow(symptom: symptom)
            }
        }
    }
}

// MARK: - Symptom Row
struct SymptomRow: View {
    let symptom: SymptomRating
    
    var body: some View {
        HStack(spacing: 6) {
            Text(symptom.symptomName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CloveColors.primaryText)
                .lineLimit(1)
            
            Spacer()
            
            Text("\(symptom.rating)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(YesterdayHelpers.symptomColor(for: symptom.rating))
        }
        .padding(.horizontal, CloveSpacing.small)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(CloveColors.background)
        )
    }
}

// MARK: - No Data View
struct NoDataView: View {
    var body: some View {
        HStack(spacing: CloveSpacing.small) {
            Image(systemName: "calendar.badge.minus")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(CloveColors.secondaryText)
            
            Text("No data from yesterday")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(CloveColors.secondaryText)
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card.opacity(0.5))
                .stroke(CloveColors.background, lineWidth: 1)
        )
    }
}

// MARK: - Helper Functions
struct YesterdayHelpers {
    static func moodEmoji(for mood: Int) -> String {
        switch mood {
        case 0...2: return "😢"
        case 3...4: return "😕"
        case 5...6: return "😐"
        case 7...8: return "🙂"
        default: return "😁"
        }
    }
    
    static func moodColor(for mood: Int) -> Color {
        switch mood {
        case 0...3: return CloveColors.error
        case 4...6: return CloveColors.secondaryText
        default: return CloveColors.success
        }
    }
    
    static func painColor(for pain: Int) -> Color {
        switch pain {
        case 0...3: return CloveColors.success
        case 4...6: return CloveColors.secondaryText
        default: return CloveColors.error
        }
    }
    
    static func energyColor(for energy: Int) -> Color {
        switch energy {
        case 0...3: return CloveColors.error
        case 4...6: return CloveColors.secondaryText
        default: return CloveColors.success
        }
    }
    
    static func symptomColor(for rating: Int) -> Color {
        switch rating {
        case 0...3: return CloveColors.success
        case 4...6: return CloveColors.secondaryText
        default: return CloveColors.error
        }
    }
}


struct MetricCard: View {
    let title: String
    let value: Int
    let emoji: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(emoji)
                .font(.system(size: 20))
            
            Text("\(value)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CloveColors.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CloveSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.small)
                .fill(CloveColors.background)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        // With yesterday's data
        YesterdaySummary(
            yesterdayLog: DailyLog(
                date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                mood: 7,
                painLevel: 4,
                energyLevel: 6,
                meals: [],
                activities: [],
                medicationsTaken: [],
                notes: nil,
                isFlareDay: false,
                symptomRatings: [
                    SymptomRating(symptomId: 1, symptomName: "Headache", rating: 8),
                    SymptomRating(symptomId: 2, symptomName: "Joint Pain", rating: 2),
                    SymptomRating(symptomId: 3, symptomName: "Fatigue", rating: 7)
                ]
            ),
            settings: UserSettings(
                trackMood: true,
                trackPain: true,
                trackEnergy: true,
                trackSymptoms: true,
                trackMeals: false,
                trackActivities: false,
                trackMeds: false,
                showFlareToggle: true,
                trackWeather: false,
                trackNotes: true,
                trackBowelMovements: true
            )
        )
        
        // Without yesterday's data
        YesterdaySummary(
            yesterdayLog: nil,
            settings: UserSettings.default
        )
    }
    .padding()
    .background(CloveColors.background)
}
