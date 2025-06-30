import SwiftUI

struct MedicationSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var newMedicationName = ""
    @State private var newMedicationDosage = ""
    @State private var newMedicationInstructions = ""
    @State private var newMedicationIsAsNeeded = false
    @State private var editingMedication: TrackedMedication? = nil
    @State private var editingName = ""
    @State private var editingDosage = ""
    @State private var editingInstructions = ""
    @State private var editingIsAsNeeded = false
    @FocusState private var isTextFieldFocused: Bool
    
    @State private var trackedMedications: [TrackedMedication] = []
    @State private var suggestions: [String] = []
    @State private var showingSuggestions = false
    @State private var recentChanges: [MedicationHistoryEntry] = []
    private let medicationRepo = MedicationRepository.shared
    private let suggestionRepo = SuggestionRepository.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.clear
                
                VStack(spacing: 0) {
                    // Header
                    MedicationSetupHeaderView()
                        .padding(.horizontal, CloveSpacing.large)
                        .padding(.top, CloveSpacing.large)
                    
                    // Add new medication section
                    AddMedicationFormView(
                        newMedicationName: $newMedicationName,
                        newMedicationDosage: $newMedicationDosage,
                        newMedicationInstructions: $newMedicationInstructions,
                        newMedicationIsAsNeeded: $newMedicationIsAsNeeded,
                        suggestions: $suggestions,
                        showingSuggestions: $showingSuggestions,
                        isTextFieldFocused: $isTextFieldFocused,
                        isAddButtonEnabled: isAddButtonEnabled,
                        onSuggestionChange: updateSuggestions,
                        onSuggestionSelect: selectSuggestion,
                        onAddMedication: addMedication
                    )
                    .padding(.top, CloveSpacing.xlarge)
                    
                    // Current medications list
                    MedicationListView(
                        trackedMedications: trackedMedications,
                        recentChanges: recentChanges,
                        editingMedication: editingMedication,
                        editingName: $editingName,
                        editingDosage: $editingDosage,
                        editingInstructions: $editingInstructions,
                        editingIsAsNeeded: $editingIsAsNeeded,
                        onEdit: startEditing,
                        onSave: saveEdit,
                        onCancel: cancelEdit,
                        onDelete: deleteMedications
                    )
                    .padding(.top, CloveSpacing.large)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(CloveColors.secondaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(CloveColors.accent)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationBackground(.thinMaterial)
        .presentationCornerRadius(20)
        .onAppear {
            loadMedications()
            loadRecentChanges()
            updateSuggestions(for: "")
        }
        .onChange(of: isTextFieldFocused) { _, focused in
            withAnimation(.easeInOut(duration: 0.2)) {
                showingSuggestions = focused
            }
        }
    }
    
    private var isAddButtonEnabled: Bool {
        !newMedicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func loadMedications() {
        trackedMedications = medicationRepo.getTrackedMedications()
    }
    
    private func loadRecentChanges() {
        // Get changes from the last 7 days
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let allHistory = medicationRepo.getMedicationHistory()
        recentChanges = allHistory.filter { $0.changeDate >= sevenDaysAgo }
    }
    
    private func updateSuggestions(for query: String) {
        suggestions = suggestionRepo.getFilteredSuggestions(for: .medications, query: query)
            .filter { suggestion in
                // Don't suggest medications that are already added
                !trackedMedications.contains { $0.name.lowercased() == suggestion.lowercased() }
            }
    }
    
    private func selectSuggestion(_ suggestion: String) {
        newMedicationName = suggestion
        isTextFieldFocused = false
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func addMedication() {
        let trimmedName = newMedicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let medication = TrackedMedication(
            name: trimmedName,
            dosage: newMedicationDosage.trimmingCharacters(in: .whitespacesAndNewlines),
            instructions: newMedicationInstructions.trimmingCharacters(in: .whitespacesAndNewlines),
            isAsNeeded: newMedicationIsAsNeeded
        )
        
        if medicationRepo.saveMedicationWithHistory(medication, changeType: "added", newValue: trimmedName) {
            // Save to suggestions for future use
            suggestionRepo.addSuggestion(trimmedName, for: .medications)
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            // Clear form
            newMedicationName = ""
            newMedicationDosage = ""
            newMedicationInstructions = ""
            newMedicationIsAsNeeded = false
            isTextFieldFocused = false
            
            // Reload list and update suggestions
            loadMedications()
            loadRecentChanges()
            updateSuggestions(for: "")
        }
    }
    
    private func startEditing(_ medication: TrackedMedication) {
        editingMedication = medication
        editingName = medication.name
        editingDosage = medication.dosage
        editingInstructions = medication.instructions
        editingIsAsNeeded = medication.isAsNeeded
    }
    
    private func saveEdit() {
        guard let medication = editingMedication, let id = medication.id else { return }
        
        let trimmedName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        if medicationRepo.updateMedication(
            id: id,
            name: trimmedName,
            dosage: editingDosage.trimmingCharacters(in: .whitespacesAndNewlines),
            instructions: editingInstructions.trimmingCharacters(in: .whitespacesAndNewlines),
            isAsNeeded: editingIsAsNeeded
        ) {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            cancelEdit()
            loadMedications()
            loadRecentChanges()
        }
    }
    
    private func cancelEdit() {
        editingMedication = nil
        editingName = ""
        editingDosage = ""
        editingInstructions = ""
        editingIsAsNeeded = false
    }
    
    private func deleteMedications(at offsets: IndexSet) {
        for index in offsets {
            let medication = trackedMedications[index]
            if let id = medication.id {
                if medicationRepo.deleteMedication(id: id) {
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
            }
        }
        loadMedications()
        loadRecentChanges()
    }
}

struct MedicationRowView: View {
    let medication: TrackedMedication
    let isEditing: Bool
    @Binding var editingName: String
    @Binding var editingDosage: String
    @Binding var editingInstructions: String
    @Binding var editingIsAsNeeded: Bool
    let onEdit: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            HStack(spacing: CloveSpacing.medium) {
                Image(systemName: medication.isAsNeeded ? "pills.circle" : "pills.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(CloveColors.accent)
                
                if isEditing {
                    VStack(alignment: .leading, spacing: CloveSpacing.small) {
                        TextField("Medication name", text: $editingName)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Dosage", text: $editingDosage)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Instructions", text: $editingInstructions)
                            .textFieldStyle(.roundedBorder)
                        
                        HStack {
                            Text("As-needed")
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.secondaryText)
                            
                            Spacer()
                            
                            CloveToggle(toggled: $editingIsAsNeeded, onColor: .accent, handleColor: .card.opacity(0.6))
                                .scaleEffect(0.8)
                        }
                    }
                    
                    HStack(spacing: CloveSpacing.medium) {
                        Button("Save") {
                            onSave()
                        }
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.accent)
                        .fontWeight(.semibold)
                        
                        Button("Cancel") {
                            onCancel()
                        }
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                        
                        Spacer()
                    }
                } else {
                    VStack(alignment: .leading, spacing: CloveSpacing.small) {
                        HStack {
                            Text(medication.name)
                                .font(CloveFonts.body())
                                .foregroundStyle(CloveColors.primaryText)
                                .fontWeight(.semibold)
                            
                            if medication.isAsNeeded {
                                Text("As needed")
                                    .font(CloveFonts.small())
                                    .foregroundStyle(CloveColors.secondaryText)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(CloveColors.secondaryText.opacity(0.1))
                                    )
                            }
                            
                            Spacer()
                        }
                        
                        if !medication.dosage.isEmpty {
                            Text(medication.dosage)
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.secondaryText)
                        }
                        
                        if !medication.instructions.isEmpty {
                            Text(medication.instructions)
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.secondaryText)
                                .italic()
                        }
                    }
                    
                    Button("Edit") {
                        onEdit()
                    }
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.accent)
                    .fontWeight(.semibold)
                }
            }
        }
        .padding(.vertical, CloveSpacing.small)
        .padding(.horizontal, CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Subviews

struct MedicationSetupHeaderView: View {
    var body: some View {
        VStack(spacing: CloveSpacing.medium) {
            Text("Manage Medications")
                .font(CloveFonts.title())
                .foregroundStyle(CloveColors.primaryText)
            
            Text("Add your regular medications to track daily adherence")
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }
}

struct AddMedicationFormView: View {
    @Binding var newMedicationName: String
    @Binding var newMedicationDosage: String
    @Binding var newMedicationInstructions: String
    @Binding var newMedicationIsAsNeeded: Bool
    @Binding var suggestions: [String]
    @Binding var showingSuggestions: Bool
    var isTextFieldFocused: FocusState<Bool>.Binding
    let isAddButtonEnabled: Bool
    let onSuggestionChange: (String) -> Void
    let onSuggestionSelect: (String) -> Void
    let onAddMedication: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            Text("Add New Medication")
                .font(CloveFonts.sectionTitle())
                .foregroundStyle(CloveColors.primaryText)
                .padding(.horizontal, CloveSpacing.large)
            
            VStack(spacing: CloveSpacing.medium) {
                // Medication name with suggestions
                MedicationNameInputView(
                    medicationName: $newMedicationName,
                    suggestions: $suggestions,
                    showingSuggestions: $showingSuggestions,
                    isTextFieldFocused: isTextFieldFocused,
                    onSuggestionChange: onSuggestionChange,
                    onSuggestionSelect: onSuggestionSelect,
                    onAddMedication: onAddMedication
                )
                
                // Dosage
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    Text("Dosage")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                    TextField("e.g., 200mg", text: $newMedicationDosage)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Instructions
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    Text("Instructions")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                    TextField("e.g., Take with food", text: $newMedicationInstructions)
                        .textFieldStyle(.roundedBorder)
                }
                
                // As-needed toggle
                HStack {
                    Text("As-needed medication")
                        .font(CloveFonts.body())
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Spacer()
                    
                    CloveToggle(toggled: $newMedicationIsAsNeeded, onColor: .accent, handleColor: .card.opacity(0.6))
                        .accessibilityLabel("As-needed medication toggle")
                }
                
                // Add button
                Button(action: onAddMedication) {
                    HStack(spacing: CloveSpacing.small) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Add Medication")
                            .font(CloveFonts.body())
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: CloveCorners.small)
                            .fill(isAddButtonEnabled ? CloveColors.accent : CloveColors.secondaryText)
                    )
                }
                .disabled(!isAddButtonEnabled)
            }
            .padding(.horizontal, CloveSpacing.large)
        }
    }
}

struct MedicationNameInputView: View {
    @Binding var medicationName: String
    @Binding var suggestions: [String]
    @Binding var showingSuggestions: Bool
    var isTextFieldFocused: FocusState<Bool>.Binding
    let onSuggestionChange: (String) -> Void
    let onSuggestionSelect: (String) -> Void
    let onAddMedication: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            Text("Medication Name *")
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)
            
            VStack(spacing: 0) {
                TextField("e.g., Ibuprofen", text: $medicationName)
                    .textFieldStyle(.roundedBorder)
                    .focused(isTextFieldFocused)
                    .onChange(of: medicationName) { _, newValue in
                        onSuggestionChange(newValue)
                    }
                    .onSubmit {
                        if !medicationName.isEmpty {
                            onAddMedication()
                        }
                    }
                
                // Suggestions dropdown
                if showingSuggestions && !suggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(action: {
                                onSuggestionSelect(suggestion)
                            }) {
                                HStack {
                                    Text(suggestion)
                                        .foregroundStyle(CloveColors.primaryText)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.clear)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if suggestion != suggestions.last {
                                Divider()
                                    .padding(.horizontal, 12)
                            }
                        }
                    }
                    .background(CloveColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                }
            }
        }
    }
}

struct MedicationListView: View {
    let trackedMedications: [TrackedMedication]
    let recentChanges: [MedicationHistoryEntry]
    let editingMedication: TrackedMedication?
    @Binding var editingName: String
    @Binding var editingDosage: String
    @Binding var editingInstructions: String
    @Binding var editingIsAsNeeded: Bool
    let onEdit: (TrackedMedication) -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let onDelete: (IndexSet) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            Text("Current Medications")
                .font(CloveFonts.sectionTitle())
                .foregroundStyle(CloveColors.primaryText)
                .padding(.horizontal, CloveSpacing.large)
            
            // Recent changes notification
            if !recentChanges.isEmpty {
                RecentChangesNotificationView(recentChanges: recentChanges)
                    .padding(.horizontal, CloveSpacing.large)
            }
            
            if trackedMedications.isEmpty {
                MedicationEmptyStateView()
            } else {
                List {
                    ForEach(trackedMedications, id: \.id) { medication in
                        MedicationRowView(
                            medication: medication,
                            isEditing: editingMedication?.id == medication.id,
                            editingName: $editingName,
                            editingDosage: $editingDosage,
                            editingInstructions: $editingInstructions,
                            editingIsAsNeeded: $editingIsAsNeeded,
                            onEdit: { onEdit(medication) },
                            onSave: onSave,
                            onCancel: onCancel
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                    .onDelete(perform: onDelete)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

struct MedicationEmptyStateView: View {
    var body: some View {
        VStack(spacing: CloveSpacing.medium) {
            Image(systemName: "pills")
                .font(.system(size: 40))
                .foregroundStyle(CloveColors.secondaryText.opacity(0.5))
            
            Text("No medications added yet")
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.secondaryText)
            
            Text("Add your first medication above to get started")
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CloveSpacing.xlarge)
    }
}

struct RecentChangesNotificationView: View {
    let recentChanges: [MedicationHistoryEntry]
    @State private var isExpanded = false
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .none
        formatter.dateStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 16))
                        .foregroundStyle(CloveColors.accent)
                    
                    Text("Recent Changes (\(recentChanges.count))")
                        .font(CloveFonts.body())
                        .foregroundStyle(CloveColors.primaryText)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(spacing: CloveSpacing.xsmall) {
                    ForEach(recentChanges.prefix(5), id: \.id) { change in
                        HStack {
                            Text("•")
                                .foregroundStyle(CloveColors.accent)
                            
                            Text(changeDescription(change))
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.primaryText)
                            
                            Spacer()
                            
                            Text(timeFormatter.string(from: change.changeDate))
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.secondaryText)
                        }
                    }
                    
                    if recentChanges.count > 5 {
                        Text("... and \(recentChanges.count - 5) more")
                            .font(CloveFonts.small())
                            .foregroundStyle(CloveColors.secondaryText)
                            .padding(.top, 2)
                    }
                }
                .padding(.leading, CloveSpacing.medium)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .padding(.vertical, CloveSpacing.small)
        .padding(.horizontal, CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.accent.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(CloveColors.accent.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func changeDescription(_ change: MedicationHistoryEntry) -> String {
        switch change.changeType {
        case "added":
            return "Added \(change.medicationName)"
        case "removed":
            return "Removed \(change.medicationName)"
        case "dosage_changed":
            return "Changed \(change.medicationName) dosage"
        case "name_changed":
            return "Renamed medication to \(change.medicationName)"
        case "instructions_changed":
            return "Updated \(change.medicationName) instructions"
        case "schedule_changed":
            return "Changed \(change.medicationName) schedule"
        default:
            return "Modified \(change.medicationName)"
        }
    }
}

#Preview {
    MedicationSetupSheet()
}
