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
    
    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var formOpacity: Double = 0
    @State private var listOpacity: Double = 0
    @State private var headerOffset: CGFloat = -20
    @State private var formOffset: CGFloat = 30
    @State private var listOffset: CGFloat = 30
    @State private var quickButtonsVisible = false
    
    @State private var trackedMedications: [TrackedMedication] = []
    @State private var suggestions: [String] = []
    @State private var showingSuggestions = false
    @State private var recentChanges: [MedicationHistoryEntry] = []
    private let medicationRepo = MedicationRepository.shared
    private let suggestionRepo = SuggestionRepository.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                // Subtle gradient background
                LinearGradient(
                    colors: [
                        Theme.shared.accent.opacity(0.02),
                        CloveColors.background,
                        Theme.shared.accent.opacity(0.01)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: CloveSpacing.xlarge) {
                        // Modern header
                        ModernMedicationHeaderView()
                            .opacity(headerOpacity)
                            .offset(y: headerOffset)
                        
                        // Add medication form
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
                            quickButtonsVisible: $quickButtonsVisible,
                            onSuggestionChange: updateSuggestions,
                            onSuggestionSelect: selectSuggestion,
                            onAddMedication: addMedication
                        )
                        .opacity(formOpacity)
                        .offset(y: formOffset)
                        
                        // Medications list
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
                        .opacity(listOpacity)
                        .offset(y: listOffset)
                        
                        Spacer(minLength: CloveSpacing.xlarge)
                    }
                    .padding(.horizontal, CloveSpacing.large)
                    .padding(.top, CloveSpacing.medium)
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
                            .foregroundStyle(Theme.shared.accent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
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
            startEntranceAnimations()
        }
        .onChange(of: isTextFieldFocused) { _, focused in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showingSuggestions = focused
            }
        }
    }
    
    private func startEntranceAnimations() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            headerOpacity = 1.0
            headerOffset = 0
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
            formOpacity = 1.0
            formOffset = 0
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
            listOpacity = 1.0
            listOffset = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            quickButtonsVisible = true
        }
    }
    
    private var isAddButtonEnabled: Bool {
        !newMedicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func loadMedications() {
        trackedMedications = medicationRepo.getTrackedMedications()
    }
    
    private func loadRecentChanges() {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let allHistory = medicationRepo.getMedicationHistory()
        recentChanges = allHistory.filter { $0.changeDate >= sevenDaysAgo }
    }
    
    private func updateSuggestions(for query: String) {
        suggestions = suggestionRepo.getFilteredSuggestions(for: .medications, query: query)
            .filter { suggestion in
                !trackedMedications.contains { $0.name.lowercased() == suggestion.lowercased() }
            }
    }
    
    private func selectSuggestion(_ suggestion: String) {
        newMedicationName = suggestion
        isTextFieldFocused = false
        
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
            suggestionRepo.addSuggestion(trimmedName, for: .medications)
            
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                newMedicationName = ""
                newMedicationDosage = ""
                newMedicationInstructions = ""
                newMedicationIsAsNeeded = false
                isTextFieldFocused = false
                isLoading = false
            }
            
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
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            editingMedication = medication
            editingName = medication.name
            editingDosage = medication.dosage
            editingInstructions = medication.instructions
            editingIsAsNeeded = medication.isAsNeeded
        }
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
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            cancelEdit()
            loadMedications()
            loadRecentChanges()
        }
    }
    
    private func cancelEdit() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            editingMedication = nil
            editingName = ""
            editingDosage = ""
            editingInstructions = ""
            editingIsAsNeeded = false
        }
    }
    
    private func deleteMedications(at offsets: IndexSet) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            for index in offsets {
                let medication = trackedMedications[index]
                if let id = medication.id {
                    if medicationRepo.deleteMedication(id: id) {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }
                }
            }
            loadMedications()
            loadRecentChanges()
        }
    }
}

// MARK: - Modern Views

struct ModernMedicationHeaderView: View {
    var body: some View {
        VStack(spacing: CloveSpacing.medium) {
            // Icon and title
            HStack(spacing: CloveSpacing.medium) {
                ZStack {
                    Circle()
                        .fill(Theme.shared.accent.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "pills.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Theme.shared.accent)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Manage Medications")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("Track daily adherence")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
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
    @Binding var quickButtonsVisible: Bool
    let onSuggestionChange: (String) -> Void
    let onSuggestionSelect: (String) -> Void
    let onAddMedication: () -> Void
    
    private let quickMedications = ["Ibuprofen", "Acetaminophen", "Aspirin", "Vitamin D"]
    private let quickDosages = ["100mg", "200mg", "500mg", "1000mg"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.large) {
            // Section header
            HStack {
                Text("Add Medication")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
            }
            
            VStack(spacing: CloveSpacing.large) {
                // Medication name
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    Text("Medication Name")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)
                    
                    VStack(spacing: 0) {
                        TextField("e.g., Ibuprofen", text: $newMedicationName)
                            .font(.system(.body, design: .rounded))
                            .padding(CloveSpacing.medium)
                            .background(
                                RoundedRectangle(cornerRadius: CloveCorners.medium)
                                    .fill(CloveColors.background)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                                            .stroke(
                                                isTextFieldFocused.wrappedValue ? Theme.shared.accent.opacity(0.5) : CloveColors.secondaryText.opacity(0.2),
                                                lineWidth: 1.5
                                            )
                                    )
                            )
                            .focused(isTextFieldFocused)
                            .onChange(of: newMedicationName) { _, newValue in
                                onSuggestionChange(newValue)
                            }
                            .onSubmit {
                                if isAddButtonEnabled {
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
                    
                    // Quick medication buttons
                    VStack(alignment: .leading, spacing: CloveSpacing.small) {
                        Text("Quick Add")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(CloveColors.secondaryText)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: CloveSpacing.small) {
                            ForEach(Array(quickMedications.enumerated()), id: \.offset) { index, medication in
                                Button(medication) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        newMedicationName = medication
                                    }
                                    
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundStyle(newMedicationName == medication ? .white : Theme.shared.accent)
                                .padding(.horizontal, CloveSpacing.medium)
                                .padding(.vertical, CloveSpacing.small)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                                        .fill(newMedicationName == medication ? Theme.shared.accent : Theme.shared.accent.opacity(0.1))
                                )
                                .scaleEffect(quickButtonsVisible ? 1.0 : 0.8)
                                .opacity(quickButtonsVisible ? 1.0 : 0)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.1), value: quickButtonsVisible)
                            }
                        }
                    }
                }
                
                // Dosage
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    Text("Dosage")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)
                    
                    TextField("e.g., 200mg", text: $newMedicationDosage)
                        .font(.system(.body, design: .rounded))
                        .padding(CloveSpacing.medium)
                        .background(
                            RoundedRectangle(cornerRadius: CloveCorners.medium)
                                .fill(CloveColors.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                                        .stroke(CloveColors.secondaryText.opacity(0.2), lineWidth: 1)
                                )
                        )
                    
                    // Quick dosage buttons
                    HStack(spacing: CloveSpacing.small) {
                        ForEach(quickDosages, id: \.self) { dosage in
                            Button(dosage) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    newMedicationDosage = dosage
                                }
                                
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(newMedicationDosage == dosage ? .white : Theme.shared.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(newMedicationDosage == dosage ? Theme.shared.accent : Theme.shared.accent.opacity(0.1))
                            )
                        }
                        
                        Spacer()
                    }
                }
                
                // Instructions
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    Text("Instructions")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)
                    
                    TextField("e.g., Take with food", text: $newMedicationInstructions)
                        .font(.system(.body, design: .rounded))
                        .padding(CloveSpacing.medium)
                        .background(
                            RoundedRectangle(cornerRadius: CloveCorners.medium)
                                .fill(CloveColors.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                                        .stroke(CloveColors.secondaryText.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                
                // As-needed toggle
                HStack(spacing: CloveSpacing.medium) {
                    Text("As-needed medication")
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            newMedicationIsAsNeeded.toggle()
                        }
                        
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }) {
                        HStack(spacing: CloveSpacing.small) {
                            Circle()
                                .fill(.white)
                                .frame(width: 18, height: 18)
                                .scaleEffect(newMedicationIsAsNeeded ? 1.0 : 0.8)
                                .offset(x: newMedicationIsAsNeeded ? 12 : -12)
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                        .frame(width: 44, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(newMedicationIsAsNeeded ? Theme.shared.accent : CloveColors.secondaryText.opacity(0.3))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(CloveSpacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .fill(CloveColors.background)
                        .overlay(
                            RoundedRectangle(cornerRadius: CloveCorners.medium)
                                .stroke(CloveColors.secondaryText.opacity(0.2), lineWidth: 1)
                        )
                )
                
                // Add button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        onAddMedication()
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
                            .font(.system(.body, design: .rounded, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                            .fill(
                                isAddButtonEnabled ? Theme.shared.accent : CloveColors.secondaryText.opacity(0.5)
                            )
                            .shadow(
                                color: isAddButtonEnabled ? Theme.shared.accent.opacity(0.3) : .clear,
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    )
                    .scaleEffect(isAddButtonEnabled ? 1.0 : 0.95)
                    .opacity(isAddButtonEnabled ? 1.0 : 0.6)
                }
                .disabled(!isAddButtonEnabled || isLoading)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isAddButtonEnabled)
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
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
            // Section header
            HStack {
                Text("Your Medications")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
                
                if !trackedMedications.isEmpty {
                    Text("\(trackedMedications.count)")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Theme.shared.accent.opacity(0.8))
                        )
                }
            }
            
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
        VStack(spacing: CloveSpacing.medium) {
            if isEditing {
                // Editing mode
                VStack(spacing: CloveSpacing.medium) {
                    HStack {
                        Text("Edit Medication")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(CloveColors.primaryText)
                        Spacer()
                    }
                    
                    VStack(spacing: CloveSpacing.medium) {
                        TextField("Medication name", text: $editingName)
                            .font(.system(.body, design: .rounded))
                            .padding(CloveSpacing.medium)
                            .background(
                                RoundedRectangle(cornerRadius: CloveCorners.medium)
                                    .fill(CloveColors.background)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                                            .stroke(Theme.shared.accent.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        
                        TextField("Dosage", text: $editingDosage)
                            .font(.system(.body, design: .rounded))
                            .padding(CloveSpacing.medium)
                            .background(
                                RoundedRectangle(cornerRadius: CloveCorners.medium)
                                    .fill(CloveColors.background)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                                            .stroke(Theme.shared.accent.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        
                        TextField("Instructions", text: $editingInstructions)
                            .font(.system(.body, design: .rounded))
                            .padding(CloveSpacing.medium)
                            .background(
                                RoundedRectangle(cornerRadius: CloveCorners.medium)
                                    .fill(CloveColors.background)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                                            .stroke(Theme.shared.accent.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        
                        // As-needed toggle for editing
                        HStack(spacing: CloveSpacing.medium) {
                            Text("As-needed medication")
                                .font(.system(.body, design: .rounded, weight: .medium))
                                .foregroundStyle(CloveColors.primaryText)
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    editingIsAsNeeded.toggle()
                                }
                                
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
                                        .fill(editingIsAsNeeded ? Theme.shared.accent : CloveColors.secondaryText.opacity(0.3))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    HStack(spacing: CloveSpacing.medium) {
                        Button("Save") {
                            onSave()
                        }
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: CloveCorners.medium)
                                .fill(CloveColors.success)
                        )
                        
                        Button("Cancel") {
                            onCancel()
                        }
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(CloveColors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: CloveCorners.medium)
                                .fill(CloveColors.secondaryText.opacity(0.1))
                        )
                    }
                }
            } else {
                // Display mode
                HStack(spacing: CloveSpacing.medium) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Theme.shared.accent.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: medication.isAsNeeded ? "pills.circle" : "pills.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.shared.accent)
                    }
                    
                    // Medication details
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(medication.name)
                                .font(.system(.body, design: .rounded, weight: .medium))
                                .foregroundStyle(CloveColors.primaryText)
                            
                            if medication.isAsNeeded {
                                Text("As needed")
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundStyle(Theme.shared.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(Theme.shared.accent.opacity(0.1))
                                            .overlay(
                                                Capsule()
                                                    .stroke(Theme.shared.accent.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            }
                            
                            Spacer()
                        }
                        
                        if !medication.dosage.isEmpty {
                            Text(medication.dosage)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(CloveColors.secondaryText)
                        }
                        
                        if !medication.instructions.isEmpty {
                            Text(medication.instructions)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(CloveColors.secondaryText)
                                .italic()
                        }
                    }
                    
                    // Actions
                    HStack(spacing: CloveSpacing.small) {
                        Button("Edit") {
                            onEdit()
                        }
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.shared.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Theme.shared.accent.opacity(0.1))
                        )
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(Color.red.opacity(0.8))
                                )
                        }
                    }
                }
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(isEditing ? Theme.shared.accent.opacity(0.05) : CloveColors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.large)
                        .stroke(
                            isEditing ? Theme.shared.accent.opacity(0.2) : Color.clear,
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isEditing)
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
                    ZStack {
                        Circle()
                            .fill(Theme.shared.accent.opacity(0.1))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.shared.accent)
                    }
                    
                    Text("Recent Changes (\(recentChanges.count))")
                        .font(.system(.body, design: .rounded, weight: .semibold))
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
                                .fill(Theme.shared.accent)
                                .frame(width: 6, height: 6)
                            
                            Text(changeDescription(change))
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(CloveColors.primaryText)
                            
                            Spacer()
                            
                            Text(timeFormatter.string(from: change.changeDate))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(CloveColors.secondaryText)
                        }
                    }
                    
                    if recentChanges.count > 5 {
                        Text("... and \(recentChanges.count - 5) more")
                            .font(.system(.caption, design: .rounded))
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
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(
                    LinearGradient(
                        colors: [Theme.shared.accent.opacity(0.08), Theme.shared.accent.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.large)
                        .stroke(Theme.shared.accent.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Theme.shared.accent.opacity(0.1), radius: 6, x: 0, y: 3)
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
            ZStack {
                Circle()
                    .fill(Theme.shared.accent.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "pills")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Theme.shared.accent.opacity(0.6))
            }
            
            VStack(spacing: CloveSpacing.small) {
                Text("No medications yet")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Text("Add your first medication above to start tracking")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(CloveColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CloveSpacing.xlarge)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.large)
                        .stroke(Theme.shared.accent.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 3)
        )
    }
}

#Preview {
    MedicationSetupSheet()
}
