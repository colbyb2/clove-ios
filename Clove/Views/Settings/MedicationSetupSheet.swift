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
    @State private var isLoading = false
    
    @State private var trackedMedications: [TrackedMedication] = []
    @State private var suggestions: [String] = []
    @State private var showingSuggestions = false
    @State private var recentChanges: [MedicationHistoryEntry] = []
    private let medicationRepo = MedicationRepository.shared
    private let suggestionRepo = SuggestionRepository.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [CloveColors.accent.opacity(0.03), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: CloveSpacing.large) {
                        // Header with gradient background
                        ModernMedicationHeaderView()
                        
                        // Add new medication section
                        ModernAddMedicationFormView(
                            newMedicationName: $newMedicationName,
                            newMedicationDosage: $newMedicationDosage,
                            newMedicationInstructions: $newMedicationInstructions,
                            newMedicationIsAsNeeded: $newMedicationIsAsNeeded,
                            suggestions: $suggestions,
                            showingSuggestions: $showingSuggestions,
                            isTextFieldFocused: $isTextFieldFocused,
                            isLoading: $isLoading,
                            isAddButtonEnabled: isAddButtonEnabled,
                            onSuggestionChange: updateSuggestions,
                            onSuggestionSelect: selectSuggestion,
                            onAddMedication: addMedication
                        )
                        
                        // Current medications list
                        ModernMedicationListView(
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
                        
                        Spacer(minLength: CloveSpacing.xlarge)
                    }
                    .padding(.horizontal, CloveSpacing.large)
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
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dismiss()
                        }
                    } label: {
                        Text("Done")
                            .font(CloveFonts.body())
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            colors: [CloveColors.accent, CloveColors.accent.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: CloveColors.accent.opacity(0.3), radius: 4, x: 0, y: 2)
                            )
                    }
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
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
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isLoading = true
        }
        
        let medication = TrackedMedication(
            name: trimmedName,
            dosage: newMedicationDosage.trimmingCharacters(in: .whitespacesAndNewlines),
            instructions: newMedicationInstructions.trimmingCharacters(in: .whitespacesAndNewlines),
            isAsNeeded: newMedicationIsAsNeeded
        )
        
        if medicationRepo.saveMedicationWithHistory(medication, changeType: "added", newValue: trimmedName) {
            // Save to suggestions for future use
            suggestionRepo.addSuggestion(trimmedName, for: .medications)
            
            // Enhanced haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                // Clear form
                newMedicationName = ""
                newMedicationDosage = ""
                newMedicationInstructions = ""
                newMedicationIsAsNeeded = false
                isTextFieldFocused = false
                isLoading = false
            }
            
            // Reload list and update suggestions
            loadMedications()
            loadRecentChanges()
            updateSuggestions(for: "")
        } else {
            withAnimation(.spring(response: 0.3)) {
                isLoading = false
            }
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

//struct MedicationSetupHeaderView: View {
//    var body: some View {
//        VStack(spacing: CloveSpacing.medium) {
//            Text("Manage Medications")
//                .font(CloveFonts.title())
//                .foregroundStyle(CloveColors.primaryText)
//            
//            Text("Add your regular medications to track daily adherence")
//                .font(CloveFonts.body())
//                .foregroundStyle(CloveColors.secondaryText)
//                .multilineTextAlignment(.center)
//        }
//    }
//}
//
//struct AddMedicationFormView: View {
//    @Binding var newMedicationName: String
//    @Binding var newMedicationDosage: String
//    @Binding var newMedicationInstructions: String
//    @Binding var newMedicationIsAsNeeded: Bool
//    @Binding var suggestions: [String]
//    @Binding var showingSuggestions: Bool
//    var isTextFieldFocused: FocusState<Bool>.Binding
//    let isAddButtonEnabled: Bool
//    let onSuggestionChange: (String) -> Void
//    let onSuggestionSelect: (String) -> Void
//    let onAddMedication: () -> Void
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: CloveSpacing.small) {
//            Text("Add New Medication")
//                .font(CloveFonts.sectionTitle())
//                .foregroundStyle(CloveColors.primaryText)
//                .padding(.horizontal, CloveSpacing.large)
//            
//            VStack(spacing: CloveSpacing.medium) {
//                // Medication name with suggestions
//                MedicationNameInputView(
//                    medicationName: $newMedicationName,
//                    suggestions: $suggestions,
//                    showingSuggestions: $showingSuggestions,
//                    isTextFieldFocused: isTextFieldFocused,
//                    onSuggestionChange: onSuggestionChange,
//                    onSuggestionSelect: onSuggestionSelect,
//                    onAddMedication: onAddMedication
//                )
//                
//                // Dosage
//                VStack(alignment: .leading, spacing: CloveSpacing.small) {
//                    Text("Dosage")
//                        .font(CloveFonts.small())
//                        .foregroundStyle(CloveColors.secondaryText)
//                    TextField("e.g., 200mg", text: $newMedicationDosage)
//                        .textFieldStyle(.roundedBorder)
//                        .accessibilityLabel("Medication dosage")
//                        .accessibilityHint("Enter the dosage amount for this medication")
//                }
//                
//                // Instructions
//                VStack(alignment: .leading, spacing: CloveSpacing.small) {
//                    Text("Instructions")
//                        .font(CloveFonts.small())
//                        .foregroundStyle(CloveColors.secondaryText)
//                    TextField("e.g., Take with food", text: $newMedicationInstructions)
//                        .textFieldStyle(.roundedBorder)
//                        .accessibilityLabel("Medication instructions")
//                        .accessibilityHint("Enter any special instructions for taking this medication")
//                }
//                
//                // As-needed toggle
//                HStack {
//                    Text("As-needed medication")
//                        .font(CloveFonts.body())
//                        .foregroundStyle(CloveColors.primaryText)
//                    
//                    Spacer()
//                    
//                    CloveToggle(toggled: $newMedicationIsAsNeeded, onColor: .accent, handleColor: .card.opacity(0.6))
//                        .accessibilityLabel("As-needed medication toggle")
//                        .accessibilityHint(newMedicationIsAsNeeded ? "Currently set as as-needed, tap to change to regular schedule" : "Currently set as regular schedule, tap to change to as-needed")
//                }
//                
//                // Add button
//                Button(action: onAddMedication) {
//                    HStack(spacing: CloveSpacing.small) {
//                        Image(systemName: "plus.circle.fill")
//                            .font(.system(size: 16))
//                        Text("Add Medication")
//                            .font(CloveFonts.body())
//                            .fontWeight(.semibold)
//                    }
//                    .foregroundStyle(.white)
//                    .frame(maxWidth: .infinity)
//                    .frame(height: 44)
//                    .background(
//                        RoundedRectangle(cornerRadius: CloveCorners.small)
//                            .fill(isAddButtonEnabled ? CloveColors.accent : CloveColors.secondaryText)
//                    )
//                }
//                .disabled(!isAddButtonEnabled)
//            }
//            .padding(.horizontal, CloveSpacing.large)
//        }
//    }
//}
//
//struct MedicationNameInputView: View {
//    @Binding var medicationName: String
//    @Binding var suggestions: [String]
//    @Binding var showingSuggestions: Bool
//    var isTextFieldFocused: FocusState<Bool>.Binding
//    let onSuggestionChange: (String) -> Void
//    let onSuggestionSelect: (String) -> Void
//    let onAddMedication: () -> Void
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: CloveSpacing.small) {
//            Text("Medication Name *")
//                .font(CloveFonts.small())
//                .foregroundStyle(CloveColors.secondaryText)
//            
//            VStack(spacing: 0) {
//                TextField("e.g., Ibuprofen", text: $medicationName)
//                    .textFieldStyle(.roundedBorder)
//                    .focused(isTextFieldFocused)
//                    .onChange(of: medicationName) { _, newValue in
//                        onSuggestionChange(newValue)
//                    }
//                    .onSubmit {
//                        if !medicationName.isEmpty {
//                            onAddMedication()
//                        }
//                    }
//                
//                // Suggestions dropdown
//                if showingSuggestions && !suggestions.isEmpty {
//                    VStack(spacing: 0) {
//                        ForEach(suggestions, id: \.self) { suggestion in
//                            Button(action: {
//                                onSuggestionSelect(suggestion)
//                            }) {
//                                HStack {
//                                    Text(suggestion)
//                                        .foregroundStyle(CloveColors.primaryText)
//                                    Spacer()
//                                }
//                                .padding(.horizontal, 12)
//                                .padding(.vertical, 10)
//                                .background(Color.clear)
//                            }
//                            .buttonStyle(PlainButtonStyle())
//                            
//                            if suggestion != suggestions.last {
//                                Divider()
//                                    .padding(.horizontal, 12)
//                            }
//                        }
//                    }
//                    .background(CloveColors.card)
//                    .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
//                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
//                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
//                }
//            }
//        }
//    }
//}
//
//struct MedicationListView: View {
//    let trackedMedications: [TrackedMedication]
//    let recentChanges: [MedicationHistoryEntry]
//    let editingMedication: TrackedMedication?
//    @Binding var editingName: String
//    @Binding var editingDosage: String
//    @Binding var editingInstructions: String
//    @Binding var editingIsAsNeeded: Bool
//    let onEdit: (TrackedMedication) -> Void
//    let onSave: () -> Void
//    let onCancel: () -> Void
//    let onDelete: (IndexSet) -> Void
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: CloveSpacing.small) {
//            Text("Current Medications")
//                .font(CloveFonts.sectionTitle())
//                .foregroundStyle(CloveColors.primaryText)
//                .padding(.horizontal, CloveSpacing.large)
//            
//            // Recent changes notification
//            if !recentChanges.isEmpty {
//                RecentChangesNotificationView(recentChanges: recentChanges)
//                    .padding(.horizontal, CloveSpacing.large)
//            }
//            
//            if trackedMedications.isEmpty {
//                MedicationEmptyStateView()
//            } else {
//                List {
//                    ForEach(trackedMedications, id: \.id) { medication in
//                        MedicationRowView(
//                            medication: medication,
//                            isEditing: editingMedication?.id == medication.id,
//                            editingName: $editingName,
//                            editingDosage: $editingDosage,
//                            editingInstructions: $editingInstructions,
//                            editingIsAsNeeded: $editingIsAsNeeded,
//                            onEdit: { onEdit(medication) },
//                            onSave: onSave,
//                            onCancel: onCancel
//                        )
//                        .listRowBackground(Color.clear)
//                        .listRowSeparator(.hidden)
//                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
//                    }
//                    .onDelete(perform: onDelete)
//                }
//                .listStyle(.plain)
//                .scrollContentBackground(.hidden)
//            }
//        }
//    }
//}
//
//struct MedicationEmptyStateView: View {
//    var body: some View {
//        VStack(spacing: CloveSpacing.medium) {
//            Image(systemName: "pills")
//                .font(.system(size: 40))
//                .foregroundStyle(CloveColors.secondaryText.opacity(0.5))
//            
//            Text("No medications added yet")
//                .font(CloveFonts.body())
//                .foregroundStyle(CloveColors.secondaryText)
//            
//            Text("Add your first medication above to get started")
//                .font(CloveFonts.small())
//                .foregroundStyle(CloveColors.secondaryText.opacity(0.7))
//                .multilineTextAlignment(.center)
//        }
//        .frame(maxWidth: .infinity)
//        .padding(.vertical, CloveSpacing.xlarge)
//    }
//}
//
//struct RecentChangesNotificationView: View {
//    let recentChanges: [MedicationHistoryEntry]
//    @State private var isExpanded = false
//    
//    private var timeFormatter: DateFormatter {
//        let formatter = DateFormatter()
//        formatter.timeStyle = .none
//        formatter.dateStyle = .short
//        return formatter
//    }
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: CloveSpacing.small) {
//            Button(action: {
//                withAnimation(.spring(response: 0.3)) {
//                    isExpanded.toggle()
//                }
//            }) {
//                HStack {
//                    Image(systemName: "clock.badge.checkmark")
//                        .font(.system(size: 16))
//                        .foregroundStyle(CloveColors.accent)
//                    
//                    Text("Recent Changes (\(recentChanges.count))")
//                        .font(CloveFonts.body())
//                        .foregroundStyle(CloveColors.primaryText)
//                        .fontWeight(.semibold)
//                    
//                    Spacer()
//                    
//                    Image(systemName: "chevron.down")
//                        .font(.system(size: 12, weight: .medium))
//                        .foregroundStyle(CloveColors.secondaryText)
//                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
//                }
//            }
//            .buttonStyle(PlainButtonStyle())
//            
//            if isExpanded {
//                VStack(spacing: CloveSpacing.xsmall) {
//                    ForEach(recentChanges.prefix(5), id: \.id) { change in
//                        HStack {
//                            Text("•")
//                                .foregroundStyle(CloveColors.accent)
//                            
//                            Text(changeDescription(change))
//                                .font(CloveFonts.small())
//                                .foregroundStyle(CloveColors.primaryText)
//                            
//                            Spacer()
//                            
//                            Text(timeFormatter.string(from: change.changeDate))
//                                .font(CloveFonts.small())
//                                .foregroundStyle(CloveColors.secondaryText)
//                        }
//                    }
//                    
//                    if recentChanges.count > 5 {
//                        Text("... and \(recentChanges.count - 5) more")
//                            .font(CloveFonts.small())
//                            .foregroundStyle(CloveColors.secondaryText)
//                            .padding(.top, 2)
//                    }
//                }
//                .padding(.leading, CloveSpacing.medium)
//                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
//            }
//        }
//        .padding(.vertical, CloveSpacing.small)
//        .padding(.horizontal, CloveSpacing.medium)
//        .background(
//            RoundedRectangle(cornerRadius: CloveCorners.medium)
//                .fill(CloveColors.accent.opacity(0.1))
//                .overlay(
//                    RoundedRectangle(cornerRadius: CloveCorners.medium)
//                        .stroke(CloveColors.accent.opacity(0.3), lineWidth: 1)
//                )
//        )
//    }
//    
//    private func changeDescription(_ change: MedicationHistoryEntry) -> String {
//        switch change.changeType {
//        case "added":
//            return "Added \(change.medicationName)"
//        case "removed":
//            return "Removed \(change.medicationName)"
//        case "dosage_changed":
//            return "Changed \(change.medicationName) dosage"
//        case "name_changed":
//            return "Renamed medication to \(change.medicationName)"
//        case "instructions_changed":
//            return "Updated \(change.medicationName) instructions"
//        case "schedule_changed":
//            return "Changed \(change.medicationName) schedule"
//        default:
//            return "Modified \(change.medicationName)"
//        }
//    }
//}

#Preview {
    MedicationSetupSheet()
}
// MARK: - Modern Views

struct ModernMedicationHeaderView: View {
    var body: some View {
        VStack(spacing: CloveSpacing.medium) {
            HStack(spacing: CloveSpacing.small) {
                Text("💊")
                    .font(.system(size: 28))
                    .scaleEffect(1.1)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                Text("Manage Medications")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [CloveColors.primaryText, CloveColors.primaryText.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text("Add your regular medications to track daily adherence")
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.vertical, CloveSpacing.large)
        .padding(.horizontal, CloveSpacing.large)
        .background(
         RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(
                    LinearGradient(
                        colors: [CloveColors.accent.opacity(0.08), CloveColors.accent.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(
                            LinearGradient(
                                colors: [CloveColors.accent.opacity(0.2), CloveColors.accent.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: CloveColors.accent.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

struct ModernAddMedicationFormView: View {
    @Binding var newMedicationName: String
    @Binding var newMedicationDosage: String
    @Binding var newMedicationInstructions: String
    @Binding var newMedicationIsAsNeeded: Bool
    @Binding var suggestions: [String]
    @Binding var showingSuggestions: Bool
    var isTextFieldFocused: FocusState<Bool>.Binding
    @Binding var isLoading: Bool
    let isAddButtonEnabled: Bool
    let onSuggestionChange: (String) -> Void
    let onSuggestionSelect: (String) -> Void
    let onAddMedication: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.large) {
            Text("Add New Medication")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(CloveColors.primaryText)
            
            VStack(spacing: CloveSpacing.large) {
                // Medication name with icon and suggestions
                ModernInputField(
                    icon: "💊",
                    title: "Medication Name",
                    placeholder: "e.g., Ibuprofen",
                    text: $newMedicationName,
                    isRequired: true,
                    isTextFieldFocused: isTextFieldFocused,
                    suggestions: $suggestions,
                    showingSuggestions: $showingSuggestions,
                    onSuggestionChange: onSuggestionChange,
                    onSuggestionSelect: onSuggestionSelect,
                    onSubmit: onAddMedication
                )
                
                // Dosage with icon and quick-select buttons
                ModernDosageField(
                    text: $newMedicationDosage
                )
                
                // Instructions with icon
                ModernInputField(
                    icon: "📝",
                    title: "Instructions",
                    placeholder: "e.g., Take with food",
                    text: $newMedicationInstructions,
                    isRequired: false
                )
                
                // As-needed toggle with flame icon
                ModernToggleField(
                    icon: "🔥",
                    title: "As-needed medication",
                    isOn: $newMedicationIsAsNeeded
                )
                
                // Add button with gradient and animation
                ModernAddButton(
                    isEnabled: isAddButtonEnabled,
                    isLoading: isLoading,
                    action: onAddMedication
                )
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

struct ModernInputField: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String
    let isRequired: Bool
    var isTextFieldFocused: FocusState<Bool>.Binding? = nil
    @Binding var suggestions: [String]
    @Binding var showingSuggestions: Bool
    let onSuggestionChange: ((String) -> Void)?
    let onSuggestionSelect: ((String) -> Void)?
    let onSubmit: (() -> Void)?
    
    init(icon: String, title: String, placeholder: String, text: Binding<String>, isRequired: Bool = false, isTextFieldFocused: FocusState<Bool>.Binding? = nil, suggestions: Binding<[String]> = .constant([]), showingSuggestions: Binding<Bool> = .constant(false), onSuggestionChange: ((String) -> Void)? = nil, onSuggestionSelect: ((String) -> Void)? = nil, onSubmit: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.isRequired = isRequired
        self.isTextFieldFocused = isTextFieldFocused
        self._suggestions = suggestions
        self._showingSuggestions = showingSuggestions
        self.onSuggestionChange = onSuggestionChange
        self.onSuggestionSelect = onSuggestionSelect
        self.onSubmit = onSubmit
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            HStack(spacing: CloveSpacing.small) {
                Text(icon)
                    .font(.system(size: 16))
                
                Text(title + (isRequired ? " *" : ""))
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.primaryText)
                    .fontWeight(.medium)
            }
            
            VStack(spacing: 0) {
                TextField(placeholder, text: $text)
                    .padding(CloveSpacing.medium)
                    .background(
                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                            .fill(CloveColors.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: CloveCorners.medium)
                                    .stroke(CloveColors.accent.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
                    )
                    .onChange(of: text) { _, newValue in
                        onSuggestionChange?(newValue)
                    }
                    .onSubmit {
                        onSubmit?()
                    }
                
                // Suggestions dropdown
                if showingSuggestions && !suggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(action: {
                                onSuggestionSelect?(suggestion)
                            }) {
                                HStack {
                                    Text(suggestion)
                                        .foregroundStyle(CloveColors.primaryText)
                                    Spacer()
                                }
                                .padding(.horizontal, CloveSpacing.medium)
                                .padding(.vertical, CloveSpacing.small)
                                .background(Color.clear)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if suggestion != suggestions.last {
                                Divider()
                                    .padding(.horizontal, CloveSpacing.medium)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                            .fill(CloveColors.card)
                            .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                }
            }
        }
    }
}

struct ModernDosageField: View {
    @Binding var text: String
    private let quickDosages = ["100mg", "200mg", "500mg", "1000mg"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            HStack(spacing: CloveSpacing.small) {
                Text("⚖️")
                    .font(.system(size: 16))
                
                Text("Dosage")
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.primaryText)
                    .fontWeight(.medium)
            }
            
            TextField("e.g., 200mg", text: $text)
                .padding(CloveSpacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .fill(CloveColors.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: CloveCorners.medium)
                                .stroke(CloveColors.accent.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
                )
            
            // Quick-select dosage buttons
            HStack(spacing: CloveSpacing.small) {
                ForEach(quickDosages, id: \.self) { dosage in
                    Button(dosage) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            text = dosage
                        }
                        
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                    .font(CloveFonts.small())
                    .foregroundStyle(text == dosage ? .white : CloveColors.accent)
                    .padding(.horizontal, CloveSpacing.small)
                    .padding(.vertical, CloveSpacing.xsmall)
                    .background(
                        RoundedRectangle(cornerRadius: CloveCorners.small)
                            .fill(text == dosage ? CloveColors.accent : CloveColors.accent.opacity(0.1))
                    )
                    .scaleEffect(text == dosage ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: text)
                }
                
                Spacer()
            }
        }
    }
}

struct ModernToggleField: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: CloveSpacing.medium) {
            HStack(spacing: CloveSpacing.small) {
                Text(icon)
                    .font(.system(size: 16))
                
                Text(title)
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.primaryText)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isOn.toggle()
                }
                
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }) {
                HStack(spacing: CloveSpacing.small) {
                    Circle()
                        .fill(.white)
                        .frame(width: 18, height: 18)
                        .scaleEffect(isOn ? 1.0 : 0.8)
                        .offset(x: isOn ? 12 : -12)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .frame(width: 44, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isOn ? CloveColors.accent : CloveColors.secondaryText.opacity(0.3))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(CloveColors.accent.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
    }
}

struct ModernAddButton: View {
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                action()
            }
        }) {
            HStack(spacing: CloveSpacing.small) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Text(isLoading ? "Adding..." : "Add Medication")
                    .font(CloveFonts.body())
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(
                        LinearGradient(
                            colors: isEnabled ? [CloveColors.accent, CloveColors.accent.opacity(0.8)] : [CloveColors.secondaryText, CloveColors.secondaryText.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: isEnabled ? CloveColors.accent.opacity(0.3) : .clear,
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            )
            .scaleEffect(isEnabled ? 1.0 : 0.95)
            .opacity(isEnabled ? 1.0 : 0.6)
        }
        .disabled(!isEnabled || isLoading)
        .buttonStyle(BounceButtonStyle())
    }
}

struct ModernMedicationListView: View {
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
        VStack(alignment: .leading, spacing: CloveSpacing.large) {
            Text("Current Medications")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(CloveColors.primaryText)
            
            // Recent changes notification
            if !recentChanges.isEmpty {
                ModernRecentChangesView(recentChanges: recentChanges)
            }
            
            if trackedMedications.isEmpty {
                ModernMedicationEmptyStateView()
            } else {
                VStack(spacing: CloveSpacing.medium) {
                    ForEach(trackedMedications, id: \.id) { medication in
                        ModernMedicationCard(
                            medication: medication,
                            isEditing: editingMedication?.id == medication.id,
                            editingName: $editingName,
                            editingDosage: $editingDosage,
                            editingInstructions: $editingInstructions,
                            editingIsAsNeeded: $editingIsAsNeeded,
                            onEdit: { onEdit(medication) },
                            onSave: onSave,
                            onCancel: onCancel,
                            onDelete: {
                                if let index = trackedMedications.firstIndex(where: { $0.id == medication.id }) {
                                    onDelete(IndexSet(integer: index))
                                }
                            }
                        )
                    }
                }
            }
        }
    }
}

struct ModernMedicationCard: View {
    let medication: TrackedMedication
    let isEditing: Bool
    @Binding var editingName: String
    @Binding var editingDosage: String
    @Binding var editingInstructions: String
    @Binding var editingIsAsNeeded: Bool
    let onEdit: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            if isEditing {
                // Editing mode - full width layout
                VStack(alignment: .leading, spacing: CloveSpacing.medium) {
                    // Header with icon and title
                    HStack(spacing: CloveSpacing.medium) {
                        Image(systemName: medication.isAsNeeded ? "pills.circle" : "pills.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [CloveColors.accent, CloveColors.accent.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(CloveColors.accent.opacity(0.1))
                            )
                        
                        Text("Edit Medication")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(CloveColors.primaryText)
                        
                        Spacer()
                    }
                    
                    // Edit fields
                    VStack(spacing: CloveSpacing.medium) {
                        ModernEditField(placeholder: "Medication name", text: $editingName)
                        ModernEditField(placeholder: "Dosage", text: $editingDosage)
                        ModernEditField(placeholder: "Instructions", text: $editingInstructions)
                        
                        // As-needed toggle - simplified for editing
                        HStack {
                            HStack(spacing: CloveSpacing.small) {
                                Text("🔥")
                                    .font(.system(size: 16))
                                
                                Text("As-needed medication")
                                    .font(CloveFonts.body())
                                    .foregroundStyle(CloveColors.primaryText)
                                    .fontWeight(.medium)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    editingIsAsNeeded.toggle()
                                }
                                
                                // Haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }) {
                                HStack(spacing: CloveSpacing.small) {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 18, height: 18)
                                        .scaleEffect(editingIsAsNeeded ? 1.0 : 0.8)
                                        .offset(x: editingIsAsNeeded ? 12 : -12)
                                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                }
                                .frame(width: 44, height: 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(editingIsAsNeeded ? CloveColors.accent : CloveColors.secondaryText.opacity(0.3))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Action buttons
                    HStack(spacing: CloveSpacing.medium) {
                        Button("Save") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                onSave()
                            }
                        }
                        .font(CloveFonts.body())
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: CloveCorners.medium)
                                .fill(
                                    LinearGradient(
                                        colors: [CloveColors.success, CloveColors.success.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: CloveColors.success.opacity(0.3), radius: 4, x: 0, y: 2)
                        )
                        .buttonStyle(BounceButtonStyle())
                        
                        Button("Cancel") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                onCancel()
                            }
                        }
                        .font(CloveFonts.body())
                        .foregroundStyle(CloveColors.secondaryText)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: CloveCorners.medium)
                                .fill(CloveColors.secondaryText.opacity(0.1))
                        )
                        .buttonStyle(BounceButtonStyle())
                    }
                }
            } else {
                // Display mode - horizontal layout
                HStack(spacing: CloveSpacing.medium) {
                    // Medication icon
                    Image(systemName: medication.isAsNeeded ? "pills.circle" : "pills.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [CloveColors.accent, CloveColors.accent.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(CloveColors.accent.opacity(0.1))
                        )
                    
                    // Medication details
                    VStack(alignment: .leading, spacing: CloveSpacing.small) {
                        HStack {
                            Text(medication.name)
                                .font(.system(.body, design: .rounded).weight(.semibold))
                                .foregroundStyle(CloveColors.primaryText)
                            
                            if medication.isAsNeeded {
                                Text("As needed")
                                    .font(CloveFonts.small())
                                    .foregroundStyle(CloveColors.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(CloveColors.accent.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(CloveColors.accent.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            }
                            
                            Spacer()
                        }
                        
                        if !medication.dosage.isEmpty {
                            Text(medication.dosage)
                                .font(CloveFonts.body())
                                .foregroundStyle(CloveColors.secondaryText)
                        }
                        
                        if !medication.instructions.isEmpty {
                            Text(medication.instructions)
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.secondaryText)
                                .italic()
                        }
                    }
                    
                    // Action buttons
                    VStack(spacing: CloveSpacing.small) {
                        Button("Edit") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                onEdit()
                            }
                        }
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.accent)
                        .fontWeight(.semibold)
                        .buttonStyle(BounceButtonStyle())
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.red)
                        }
                        .buttonStyle(BounceButtonStyle())
                    }
                }
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(
                    isEditing ?
                    LinearGradient(
                        colors: [CloveColors.accent.opacity(0.05), CloveColors.accent.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [CloveColors.card, CloveColors.card],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(
                            LinearGradient(
                                colors: isEditing ?
                                [CloveColors.accent.opacity(0.3), CloveColors.accent.opacity(0.2)] :
                                [CloveColors.accent.opacity(0.1), CloveColors.accent.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

struct ModernEditField: View {
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        TextField(placeholder, text: $text)
            .padding(CloveSpacing.small)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.small)
                    .fill(CloveColors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: CloveCorners.small)
                            .stroke(CloveColors.accent.opacity(0.2), lineWidth: 1)
                    )
            )
    }
}

struct ModernRecentChangesView: View {
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
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 16))
                        .foregroundStyle(CloveColors.accent)
                    
                    Text("Recent Changes (\(recentChanges.count))")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(spacing: CloveSpacing.small) {
                    ForEach(recentChanges.prefix(5), id: \.id) { change in
                        HStack {
                            Circle()
                                .fill(CloveColors.accent)
                                .frame(width: 6, height: 6)
                            
                            Text(changeDescription(change))
                                .font(CloveFonts.body())
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
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(
                    LinearGradient(
                        colors: [CloveColors.accent.opacity(0.08), CloveColors.accent.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(CloveColors.accent.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: CloveColors.accent.opacity(0.1), radius: 6, x: 0, y: 3)
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

struct ModernMedicationEmptyStateView: View {
    var body: some View {
        VStack(spacing: CloveSpacing.large) {
            Image(systemName: "pills")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [CloveColors.accent.opacity(0.6), CloveColors.accent.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: CloveSpacing.small) {
                Text("No medications added yet")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Text("Add your first medication above to get started")
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CloveSpacing.xlarge)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(CloveColors.accent.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 2)
        )
    }
}

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
