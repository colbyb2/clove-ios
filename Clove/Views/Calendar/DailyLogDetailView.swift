import SwiftUI

struct DailyLogDetailView: View {
    let log: DailyLog
    @Environment(\.dismiss) private var dismiss
    @State private var trackedSymptoms: [TrackedSymptom] = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: CloveSpacing.large) {
                    // Header section
                    headerSection
                    
                    // Weather section
                    if let weather = log.weather {
                        weatherSection(weather: weather)
                    }
                    
                    // Mental & Physical Health section
                    if hasPhysicalMentalData {
                        physicalMentalSection
                    }
                    
                    // Symptoms section
                    if !log.symptomRatings.isEmpty {
                        symptomsSection
                    }
                    
                    // Activities & Lifestyle section
                    if hasLifestyleData {
                        lifestyleSection
                    }
                    
                    // Notes section
                    if let notes = log.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        notesSection(notes: notes)
                    }
                    
                    // Flare day indicator
                    if log.isFlareDay {
                        flareDaySection
                    }
                    
                    // Empty state if no data
                    if !hasAnyData {
                        EmptyStateView(
                            icon: "doc.text",
                            title: "No Data Recorded",
                            subtitle: "No information was logged for this day"
                        )
                    }
                }
                .padding(.horizontal, CloveSpacing.medium)
                .padding(.bottom, CloveSpacing.xlarge)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.shared.accent)
                    .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        editThisDay()
                    }
                    .foregroundStyle(Theme.shared.accent)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            loadTrackedSymptoms()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: CloveSpacing.small) {
            Text(log.date.formatted(.dateTime.weekday(.wide)))
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)
            
            Text(log.date.formatted(date: .abbreviated, time: .omitted))
                .font(CloveFonts.title())
                .foregroundStyle(CloveColors.primaryText)
        }
        .padding(.top, CloveSpacing.medium)
    }
    
    // MARK: - Physical & Mental Health Section
    private var physicalMentalSection: some View {
        VStack(spacing: CloveSpacing.medium) {
            SectionHeaderView(title: "Physical & Mental Health", emoji: "🩺")
            
            VStack(spacing: CloveSpacing.medium) {
                if let mood = log.mood {
                    RatingDisplayView(
                        value: mood,
                        maxValue: 10,
                        label: "Mood",
                        emoji: "😊",
                        color: moodColor(for: mood)
                    )
                }
                
                if let pain = log.painLevel {
                    ProgressRatingView(
                        value: pain,
                        maxValue: 10,
                        label: "Pain Level",
                        color: painColor(for: pain)
                    )
                }
                
                if let energy = log.energyLevel {
                    ProgressRatingView(
                        value: energy,
                        maxValue: 10,
                        label: "Energy Level",
                        color: energyColor(for: energy)
                    )
                }
            }
        }
    }
    
    // MARK: - Symptoms Section
    private var symptomsSection: some View {
        VStack(spacing: CloveSpacing.medium) {
            SectionHeaderView(title: "Symptoms", emoji: "🩹")
            
            VStack(spacing: CloveSpacing.small) {
                ForEach(log.symptomRatings, id: \.symptomId) { symptom in
                    ProgressRatingView(
                        value: symptom.rating,
                        maxValue: 10,
                        label: symptom.symptomName,
                        color: symptomColor(for: symptom.rating)
                    )
                }
            }
        }
    }
    
    // MARK: - Lifestyle Section
    private var lifestyleSection: some View {
        VStack(spacing: CloveSpacing.medium) {
            SectionHeaderView(title: "Activities & Lifestyle", emoji: "🌟")
            
            VStack(spacing: CloveSpacing.medium) {
                if !log.meals.isEmpty {
                    VStack(alignment: .leading, spacing: CloveSpacing.small) {
                        HStack {
                            Text("🍎")
                                .font(.system(size: 16))
                            Text("Meals")
                                .font(CloveFonts.body())
                                .foregroundStyle(CloveColors.primaryText)
                            Spacer()
                        }
                        .padding(.horizontal, CloveSpacing.medium)
                        
                       TagListView(items: log.meals, color: CloveColors.green)
                    }
                }
                
                if !log.activities.isEmpty {
                    VStack(alignment: .leading, spacing: CloveSpacing.small) {
                        HStack {
                            Text("🏃")
                                .font(.system(size: 16))
                            Text("Activities")
                                .font(CloveFonts.body())
                                .foregroundStyle(CloveColors.primaryText)
                            Spacer()
                        }
                        .padding(.horizontal, CloveSpacing.medium)
                        
                       TagListView(items: log.activities, color: CloveColors.blue)
                    }
                }
                
                if !log.medicationAdherence.isEmpty {
                    VStack(alignment: .leading, spacing: CloveSpacing.small) {
                        HStack {
                            Text("💊")
                                .font(.system(size: 16))
                            Text("Medications")
                                .font(CloveFonts.body())
                                .foregroundStyle(CloveColors.primaryText)
                            Spacer()
                        }
                        .padding(.horizontal, CloveSpacing.medium)
                        
                        MedicationAdherenceView(adherence: log.medicationAdherence)
                    }
                }
            }
        }
    }
    
    // MARK: - Notes Section
    private func notesSection(notes: String) -> some View {
        VStack(spacing: CloveSpacing.medium) {
            SectionHeaderView(title: "Notes", emoji: "📝")
            NotesDisplayView(notes: notes)
        }
    }
    
    // MARK: - Flare Day Section
    private var flareDaySection: some View {
        HStack(spacing: CloveSpacing.medium) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Flare Day")
                    .font(CloveFonts.sectionTitle())
                    .foregroundStyle(CloveColors.primaryText)
                
                Text("This was marked as a flare-up day")
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
            }
            
            Spacer()
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Weather Section
    private func weatherSection(weather: String) -> some View {
        VStack(spacing: CloveSpacing.medium) {
            SectionHeaderView(title: "Weather", emoji: "🌤️")
            
            HStack(spacing: CloveSpacing.medium) {
                // Weather emoji display
                Text(weatherEmoji(for: weather))
                    .font(.system(size: 48))
                    .scaleEffect(1.0)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(weather)
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("Weather conditions")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
            }
            .padding(CloveSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(weatherBackgroundColor(for: weather))
                    .overlay(
                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                            .stroke(weatherBorderColor(for: weather), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Helper Properties
    private var hasPhysicalMentalData: Bool {
        log.mood != nil || log.painLevel != nil || log.energyLevel != nil
    }
    
    private var hasLifestyleData: Bool {
        !log.meals.isEmpty || !log.activities.isEmpty || !log.medicationAdherence.isEmpty
    }
    
    private var hasAnyData: Bool {
        hasPhysicalMentalData || !log.symptomRatings.isEmpty || hasLifestyleData || 
        (log.notes != nil && !log.notes!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ||
        log.isFlareDay || log.weather != nil
    }
    
    // MARK: - Helper Functions
    private func loadTrackedSymptoms() {
        trackedSymptoms = SymptomsRepo.shared.getTrackedSymptoms()
    }
    
    private func editThisDay() {
        // Navigate to Today tab and set the date for editing
        NavigationCoordinator.shared.editDayInTodayView(date: log.date)
        
        // Dismiss this view
        dismiss()
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func moodColor(for mood: Int) -> Color {
        switch mood {
        case 8...10: return CloveColors.green
        case 6...7: return CloveColors.blue
        case 4...5: return CloveColors.yellow
        case 2...3: return CloveColors.orange
        default: return CloveColors.red
        }
    }
    
    private func painColor(for pain: Int) -> Color {
        switch pain {
        case 8...10: return CloveColors.red
        case 5...7: return CloveColors.orange
        case 3...4: return CloveColors.yellow
        case 1...2: return CloveColors.blue
        default: return CloveColors.green
        }
    }
    
    private func energyColor(for energy: Int) -> Color {
        switch energy {
        case 8...10: return CloveColors.green
        case 5...7: return CloveColors.blue
        case 3...4: return CloveColors.yellow
        case 1...2: return CloveColors.orange
        default: return CloveColors.red
        }
    }
    
    private func symptomColor(for rating: Int) -> Color {
        painColor(for: rating) // Use same color scale as pain
    }
    
    private func weatherEmoji(for weather: String) -> String {
        switch weather {
        case "Sunny": return "☀️"
        case "Cloudy": return "☁️"
        case "Rainy": return "🌧️"
        case "Stormy": return "⛈️"
        case "Snow": return "❄️"
        case "Gloomy": return "🌫️"
        default: return "🌤️"
        }
    }
    
    private func weatherBackgroundColor(for weather: String) -> Color {
        switch weather {
        case "Sunny": return Color.yellow.opacity(0.1)
        case "Cloudy": return Color.gray.opacity(0.1)
        case "Rainy": return Color.blue.opacity(0.1)
        case "Stormy": return Color.purple.opacity(0.1)
        case "Snow": return Color.cyan.opacity(0.1)
        case "Gloomy": return Color.gray.opacity(0.15)
        default: return Color.blue.opacity(0.05)
        }
    }
    
    private func weatherBorderColor(for weather: String) -> Color {
        switch weather {
        case "Sunny": return Color.yellow.opacity(0.3)
        case "Cloudy": return Color.gray.opacity(0.3)
        case "Rainy": return Color.blue.opacity(0.3)
        case "Stormy": return Color.purple.opacity(0.3)
        case "Snow": return Color.cyan.opacity(0.3)
        case "Gloomy": return Color.gray.opacity(0.4)
        default: return Color.blue.opacity(0.2)
        }
    }
}

// MARK: - Medication Adherence View
struct MedicationAdherenceView: View {
    let adherence: [MedicationAdherence]
    
    var body: some View {
        VStack(spacing: CloveSpacing.small) {
            ForEach(adherence.indices, id: \.self) { index in
                let medication = adherence[index]
                
               if !medication.isAsNeeded {
                   HStack(spacing: CloveSpacing.medium) {
                       // Status indicator
                       Image(systemName: medication.wasTaken ? "checkmark.circle.fill" : "circle")
                           .font(.system(size: 20))
                           .foregroundStyle(medication.wasTaken ? CloveColors.success : CloveColors.secondaryText)
                       
                       // Medication info
                       VStack(alignment: .leading, spacing: 2) {
                           Text(medication.medicationName)
                               .font(CloveFonts.body())
                               .foregroundStyle(CloveColors.primaryText)
                               .fontWeight(.medium)
                           
                           if medication.isAsNeeded || medication.medicationId == -1 {
                               Text(medication.medicationId == -1 ? "One-time" : "As needed")
                                   .font(CloveFonts.small())
                                   .foregroundStyle(CloveColors.secondaryText)
                                   .padding(.horizontal, 6)
                                   .padding(.vertical, 2)
                                   .background(
                                       RoundedRectangle(cornerRadius: 4)
                                           .fill(CloveColors.secondaryText.opacity(0.1))
                                   )
                           }
                       }
                       
                       Spacer()
                       
                       // Status text
                       Text(medication.wasTaken ? "Taken" : "Not taken")
                           .font(CloveFonts.small())
                           .foregroundStyle(medication.wasTaken ? CloveColors.success : CloveColors.secondaryText)
                           .fontWeight(.medium)
                   }
                   .padding(.horizontal, CloveSpacing.medium)
                   .padding(.vertical, CloveSpacing.small)
                   .background(
                       RoundedRectangle(cornerRadius: CloveCorners.small)
                           .fill(medication.wasTaken ? CloveColors.success.opacity(0.05) : CloveColors.card)
                           .overlay(
                               RoundedRectangle(cornerRadius: CloveCorners.small)
                                   .stroke(medication.wasTaken ? CloveColors.success.opacity(0.2) : Color.clear, lineWidth: 1)
                           )
                   )
                }
            }
        }
    }
}

#Preview {
    DailyLogDetailView(
        log: DailyLog(
            date: Date(),
            mood: 7,
            painLevel: 4,
            energyLevel: 8,
            meals: ["Breakfast", "Lunch", "Dinner"],
            activities: ["Walking", "Reading"],
            medicationsTaken: ["Ibuprofen", "Vitamin D"],
            notes: "Had a good day overall. Felt energetic in the morning but pain increased in the afternoon. The weather was nice so I was able to go for a walk.",
            isFlareDay: false,
            weather: "Sunny",
            symptomRatings: [
                SymptomRating(symptomId: 1, symptomName: "Headache", rating: 3),
                SymptomRating(symptomId: 2, symptomName: "Fatigue", rating: 6)
            ]
        )
    )
}
