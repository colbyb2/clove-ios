import SwiftUI

struct DataExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategories: Set<ExportCategory> = []
    @State private var selectedSymptoms: Set<Int64> = []
    @State private var availableSymptoms: [TrackedSymptom] = []
    @State private var isLoading = false
    @State private var showShareSheet = false
    @State private var exportedFileURL: URL?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    private let dataManager = DataManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: CloveSpacing.large) {
                        // Header info
                        VStack(alignment: .leading, spacing: CloveSpacing.small) {
                            Text("Export Your Health Data")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(CloveColors.primaryText)
                            
                            Text("Select which data you'd like to include in your CSV export. This file can be opened in spreadsheet apps or shared with healthcare providers.")
                                .font(.system(size: 16))
                                .foregroundStyle(CloveColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        // Main categories section
                        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
                            HStack {
                                Text("Health Metrics")
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundStyle(CloveColors.primaryText)
                                
                                Spacer()
                                
                                Button(selectedCategories.count == ExportCategory.allCases.count ? "Deselect All" : "Select All") {
                                    if selectedCategories.count == ExportCategory.allCases.count {
                                        selectedCategories.removeAll()
                                    } else {
                                        selectedCategories = Set(ExportCategory.allCases)
                                    }
                                    
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.shared.accent)
                            }
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: CloveSpacing.small) {
                                ForEach(ExportCategory.allCases, id: \.self) { category in
                                    CategoryToggleCard(
                                        category: category,
                                        isSelected: selectedCategories.contains(category)
                                    ) {
                                        if selectedCategories.contains(category) {
                                            selectedCategories.remove(category)
                                        } else {
                                            selectedCategories.insert(category)
                                        }
                                        
                                        let selectionFeedback = UISelectionFeedbackGenerator()
                                        selectionFeedback.selectionChanged()
                                    }
                                }
                            }
                        }
                        
                        // Symptoms section
                        if !availableSymptoms.isEmpty {
                            VStack(alignment: .leading, spacing: CloveSpacing.medium) {
                                HStack {
                                    Text("Symptoms")
                                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                                        .foregroundStyle(CloveColors.primaryText)
                                    
                                    Spacer()
                                    
                                    Button(selectedSymptoms.count == availableSymptoms.count ? "Deselect All" : "Select All") {
                                        if selectedSymptoms.count == availableSymptoms.count {
                                            selectedSymptoms.removeAll()
                                        } else {
                                            selectedSymptoms = Set(availableSymptoms.compactMap { $0.id })
                                        }
                                        
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                        impactFeedback.impactOccurred()
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.shared.accent)
                                }
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: CloveSpacing.small) {
                                    ForEach(availableSymptoms, id: \.id) { symptom in
                                        SymptomToggleCard(
                                            symptom: symptom,
                                            isSelected: selectedSymptoms.contains(symptom.id ?? 0)
                                        ) {
                                            if let symptomId = symptom.id {
                                                if selectedSymptoms.contains(symptomId) {
                                                    selectedSymptoms.remove(symptomId)
                                                } else {
                                                    selectedSymptoms.insert(symptomId)
                                                }
                                                
                                                let selectionFeedback = UISelectionFeedbackGenerator()
                                                selectionFeedback.selectionChanged()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(CloveSpacing.medium)
                }
                
                // Bottom action bar
                VStack(spacing: CloveSpacing.small) {
                    Divider()
                    
                    HStack(spacing: CloveSpacing.medium) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundStyle(CloveColors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: CloveCorners.medium)
                                .fill(CloveColors.background)
                        )
                        
                        Button(action: {
                            exportData()
                        }) {
                            HStack(spacing: CloveSpacing.small) {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                
                                Text(isLoading ? "Exporting..." : "Export CSV")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: CloveCorners.medium)
                                    .fill(hasSelections ? Theme.shared.accent : CloveColors.secondaryText)
                            )
                        }
                        .disabled(!hasSelections || isLoading)
                        .accessibilityLabel("Export selected data")
                        .accessibilityHint("Creates and shares a CSV file with your selected health data")
                    }
                    .padding(CloveSpacing.medium)
                }
                .background(CloveColors.card)
            }
            .background(CloveColors.background)
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.shared.accent)
                }
            }
        }
        .onAppear {
            loadAvailableSymptoms()
            // Pre-select all categories by default
            selectedCategories = Set(ExportCategory.allCases)
        }
        .sheet(isPresented: $showShareSheet) {
            if let fileURL = exportedFileURL {
                ShareSheet(items: [fileURL])
            }
        }
        .alert("Export Error", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasSelections: Bool {
        !selectedCategories.isEmpty || !selectedSymptoms.isEmpty
    }
    
    // MARK: - Helper Methods
    
    private func loadAvailableSymptoms() {
        availableSymptoms = SymptomsRepo.shared.getTrackedSymptoms()
        // Pre-select all symptoms by default
        selectedSymptoms = Set(availableSymptoms.compactMap { $0.id })
    }
    
    private func exportData() {
        isLoading = true
        
        // Haptic feedback for export start
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        dataManager.exportToCSV(
            categories: selectedCategories,
            symptomIds: selectedSymptoms
        ) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let fileURL):
                    self.exportedFileURL = fileURL
                    self.showShareSheet = true
                    
                    // Success haptic feedback
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                    
                    ToastManager.shared.showToast(
                        message: "CSV export created successfully",
                        color: CloveColors.success,
                        icon: Image(systemName: "checkmark.circle")
                    )
                    
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                    
                    // Error haptic feedback
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.error)
                    
                    ToastManager.shared.showToast(
                        message: "Export failed",
                        color: CloveColors.error,
                        icon: Image(systemName: "exclamationmark.triangle")
                    )
                }
            }
        }
    }
}

// MARK: - Export Category Enum
enum ExportCategory: String, CaseIterable {
    case date = "Date"
    case mood = "Mood"
    case pain = "Pain Level"
    case energy = "Energy Level"
    case flareDay = "Flare Day"
    case weather = "Weather"
    case bowelMovements = "Bowel Movements"
    case medications = "Medications"
    case meals = "Meals"
    case activities = "Activities"
    case notes = "Notes"
    
    var icon: String {
        switch self {
        case .date: return "calendar"
        case .mood: return "face.smiling"
        case .pain: return "cross.case"
        case .energy: return "bolt"
        case .flareDay: return "flame"
        case .weather: return "cloud.sun"
        case .bowelMovements: return "toilet"
        case .medications: return "pills"
        case .meals: return "fork.knife"
        case .activities: return "figure.run"
        case .notes: return "note.text"
        }
    }
    
    var description: String {
        switch self {
        case .date: return "Log dates"
        case .mood: return "Daily mood ratings"
        case .pain: return "Pain level scores"
        case .energy: return "Energy level scores"
        case .flareDay: return "Flare day indicators"
        case .weather: return "Weather conditions"
        case .bowelMovements: return "Bristol stool chart data"
        case .medications: return "Medication adherence"
        case .meals: return "Daily meals logged"
        case .activities: return "Daily activities logged"
        case .notes: return "Log notes"
        }
    }
}

// MARK: - Category Toggle Card
struct CategoryToggleCard: View {
    let category: ExportCategory
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: CloveSpacing.small) {
                Image(systemName: category.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(isSelected ? Theme.shared.accent : CloveColors.secondaryText)
                
                Text(category.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CloveColors.primaryText)
                    .lineLimit(1)
                
                Text(category.description)
                    .font(.system(size: 12))
                    .foregroundStyle(CloveColors.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(CloveSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(isSelected ? Theme.shared.accent.opacity(0.1) : CloveColors.card)
                    .stroke(isSelected ? Theme.shared.accent : CloveColors.background, lineWidth: 2)
            )
        }
        .accessibilityLabel("\(category.rawValue) export option")
        .accessibilityHint(isSelected ? "Currently selected, tap to deselect" : "Currently not selected, tap to select")
    }
}

// MARK: - Symptom Toggle Card
struct SymptomToggleCard: View {
    let symptom: TrackedSymptom
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: CloveSpacing.small) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? Theme.shared.accent : CloveColors.secondaryText)
                
                Text(symptom.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CloveColors.primaryText)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? Theme.shared.accent : CloveColors.secondaryText)
            }
            .padding(CloveSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(isSelected ? Theme.shared.accent.opacity(0.1) : CloveColors.card)
                    .stroke(isSelected ? Theme.shared.accent : CloveColors.background, lineWidth: 1)
            )
        }
        .accessibilityLabel("\(symptom.name) symptom export option")
        .accessibilityHint(isSelected ? "Currently selected, tap to deselect" : "Currently not selected, tap to select")
    }
}

#Preview {
    DataExportSheet()
}
