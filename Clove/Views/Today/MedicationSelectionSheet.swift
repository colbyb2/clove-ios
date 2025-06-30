import SwiftUI

struct MedicationSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var medicationAdherence: [MedicationAdherence]
    
    @State private var trackedMedications: [TrackedMedication] = []
    @State private var oneTimeMedication = ""
    @State private var showingOneTimeMedication = false
    @FocusState private var isOneTimeFocused: Bool
    
    private let medicationRepo = MedicationRepository.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                MedicationHeaderView()
                    .padding(.horizontal, CloveSpacing.large)
                    .padding(.top, CloveSpacing.large)
                
                ScrollView {
                    VStack(spacing: CloveSpacing.medium) {
                        // Regular medications checklist
                        if !trackedMedications.isEmpty {
                            RegularMedicationsView(
                                trackedMedications: trackedMedications,
                                medicationAdherence: $medicationAdherence
                            )
                        }
                        
                        // One-time medication section
                        OneTimeMedicationView(
                            oneTimeMedication: $oneTimeMedication,
                            showingOneTimeMedication: $showingOneTimeMedication,
                            isOneTimeFocused: $isOneTimeFocused,
                            medicationAdherence: $medicationAdherence
                        )
                        
                        // Empty state
                        if trackedMedications.isEmpty && medicationAdherence.isEmpty {
                            MedicationEmptyChecklistView()
                        }
                    }
                    .padding(.horizontal, CloveSpacing.large)
                    .padding(.bottom, CloveSpacing.large)
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
            syncMedicationAdherence()
        }
    }
    
    private func loadMedications() {
        trackedMedications = medicationRepo.getTrackedMedications()
    }
    
    private func syncMedicationAdherence() {
        // Create adherence entries for any tracked medications not already in the list
        for medication in trackedMedications {
            guard let medicationId = medication.id else { continue }
            
            // Check if we already have an adherence entry for this medication
            if !medicationAdherence.contains(where: { $0.medicationId == medicationId }) {
                let adherence = MedicationAdherence(
                    medicationId: medicationId,
                    medicationName: medication.name,
                    wasTaken: false,
                    isAsNeeded: medication.isAsNeeded
                )
                medicationAdherence.append(adherence)
            }
        }
        
        // Remove adherence entries for medications that are no longer tracked
        let trackedIds = Set(trackedMedications.compactMap { $0.id })
        medicationAdherence.removeAll { adherence in
            !trackedIds.contains(adherence.medicationId) && adherence.medicationId != -1 // Keep one-time meds (-1 ID)
        }
    }
}

// MARK: - Subviews

struct MedicationHeaderView: View {
    var body: some View {
        VStack(spacing: CloveSpacing.medium) {
            HStack {
                Text("💊")
                    .font(.system(size: 24))
                Text("Medication Tracking")
                    .font(CloveFonts.title())
                    .foregroundStyle(CloveColors.primaryText)
            }
            
            Text("Mark which medications you've taken today")
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }
}

struct RegularMedicationsView: View {
    let trackedMedications: [TrackedMedication]
    @Binding var medicationAdherence: [MedicationAdherence]
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            Text("Regular Medications")
                .font(CloveFonts.sectionTitle())
                .foregroundStyle(CloveColors.primaryText)
            
            VStack(spacing: CloveSpacing.small) {
                ForEach(trackedMedications, id: \.id) { medication in
                    MedicationChecklistRow(
                        medication: medication,
                        medicationAdherence: $medicationAdherence
                    )
                }
            }
        }
    }
}

struct MedicationChecklistRow: View {
    let medication: TrackedMedication
    @Binding var medicationAdherence: [MedicationAdherence]
    
    private var adherence: Binding<MedicationAdherence?> {
        Binding<MedicationAdherence?>(
            get: {
                medicationAdherence.first { $0.medicationId == medication.id }
            },
            set: { newValue in
                if let newValue = newValue {
                    if let index = medicationAdherence.firstIndex(where: { $0.medicationId == medication.id }) {
                        medicationAdherence[index] = newValue
                    }
                }
            }
        )
    }
    
    var body: some View {
        HStack(spacing: CloveSpacing.medium) {
            Button(action: {
                toggleMedication()
            }) {
                Image(systemName: (adherence.wrappedValue?.wasTaken ?? false) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle((adherence.wrappedValue?.wasTaken ?? false) ? CloveColors.success : CloveColors.secondaryText)
            }
            .accessibilityLabel("\(medication.name) \((adherence.wrappedValue?.wasTaken ?? false) ? "taken" : "not taken")")
            
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
        }
        .padding(.vertical, CloveSpacing.small)
        .padding(.horizontal, CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            toggleMedication()
        }
    }
    
    private func toggleMedication() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if var currentAdherence = adherence.wrappedValue {
            currentAdherence.wasTaken.toggle()
            adherence.wrappedValue = currentAdherence
        }
    }
}

struct OneTimeMedicationView: View {
    @Binding var oneTimeMedication: String
    @Binding var showingOneTimeMedication: Bool
    var isOneTimeFocused: FocusState<Bool>.Binding
    @Binding var medicationAdherence: [MedicationAdherence]
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            HStack {
                Text("One-Time Medications")
                    .font(CloveFonts.sectionTitle())
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
                
                if !showingOneTimeMedication {
                    Button("Add") {
                        showingOneTimeMedication = true
                        isOneTimeFocused.wrappedValue = true
                    }
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.accent)
                    .fontWeight(.semibold)
                }
            }
            
            // Show one-time medications that were added
            let oneTimeMeds = medicationAdherence.filter { $0.medicationId == -1 }
            ForEach(oneTimeMeds.indices, id: \.self) { index in
                OneTimeMedicationRow(
                    adherence: $medicationAdherence[medicationAdherence.firstIndex { $0.medicationId == -1 && $0.medicationName == oneTimeMeds[index].medicationName }!],
                    onRemove: {
                        removeOneTimeMedication(oneTimeMeds[index])
                    }
                )
            }
            
            // Add new one-time medication input
            if showingOneTimeMedication {
                HStack(spacing: CloveSpacing.medium) {
                    TextField("Medication name", text: $oneTimeMedication)
                        .textFieldStyle(.roundedBorder)
                        .focused(isOneTimeFocused)
                        .onSubmit {
                            addOneTimeMedication()
                        }
                    
                    Button("Add") {
                        addOneTimeMedication()
                    }
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.accent)
                    .fontWeight(.semibold)
                    .disabled(oneTimeMedication.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button("Cancel") {
                        cancelOneTimeMedication()
                    }
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
                }
            }
        }
    }
    
    private func addOneTimeMedication() {
        let trimmed = oneTimeMedication.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Add one-time medication with ID -1 to distinguish from regular medications
        let adherence = MedicationAdherence(
            medicationId: -1,
            medicationName: trimmed,
            wasTaken: true, // Mark as taken by default since they're adding it
            isAsNeeded: true
        )
        
        medicationAdherence.append(adherence)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Reset form
        oneTimeMedication = ""
        showingOneTimeMedication = false
        isOneTimeFocused.wrappedValue = false
    }
    
    private func cancelOneTimeMedication() {
        oneTimeMedication = ""
        showingOneTimeMedication = false
        isOneTimeFocused.wrappedValue = false
    }
    
    private func removeOneTimeMedication(_ adherence: MedicationAdherence) {
        medicationAdherence.removeAll { $0.medicationId == adherence.medicationId && $0.medicationName == adherence.medicationName }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

struct OneTimeMedicationRow: View {
    @Binding var adherence: MedicationAdherence
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: CloveSpacing.medium) {
            Button(action: {
                toggleMedication()
            }) {
                Image(systemName: adherence.wasTaken ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(adherence.wasTaken ? CloveColors.success : CloveColors.secondaryText)
            }
            
            Text(adherence.medicationName)
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.primaryText)
                .fontWeight(.semibold)
            
            Text("One-time")
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(CloveColors.accent.opacity(0.1))
                )
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(CloveColors.secondaryText)
            }
        }
        .padding(.vertical, CloveSpacing.small)
        .padding(.horizontal, CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            toggleMedication()
        }
    }
    
    private func toggleMedication() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        adherence.wasTaken.toggle()
    }
}

struct MedicationEmptyChecklistView: View {
    var body: some View {
        VStack(spacing: CloveSpacing.medium) {
            Image(systemName: "pills")
                .font(.system(size: 40))
                .foregroundStyle(CloveColors.secondaryText.opacity(0.5))
            
            Text("No medications to track")
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.secondaryText)
            
            Text("Add regular medications in Settings, or add a one-time medication above")
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CloveSpacing.xlarge)
    }
}

#Preview {
    MedicationSelectionSheet(medicationAdherence: .constant([]))
}
