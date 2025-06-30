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
                        // Modern Header
                        ModernMedicationTrackingHeaderView()
                        
                        // Regular medications checklist
                        if !trackedMedications.isEmpty {
                            ModernRegularMedicationsCard(
                                trackedMedications: trackedMedications,
                                medicationAdherence: $medicationAdherence
                            )
                        }
                        
                        // One-time medication section
                        ModernOneTimeMedicationCard(
                            oneTimeMedication: $oneTimeMedication,
                            showingOneTimeMedication: $showingOneTimeMedication,
                            isOneTimeFocused: $isOneTimeFocused,
                            medicationAdherence: $medicationAdherence
                        )
                        
                        // Empty state
                        if trackedMedications.isEmpty && medicationAdherence.isEmpty {
                            ModernMedicationEmptyChecklistCard()
                        }
                        
                        Spacer(minLength: CloveSpacing.xlarge)
                    }
                    .padding(.horizontal, CloveSpacing.large)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dismiss()
                        }
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

#Preview {
    MedicationSelectionSheet(medicationAdherence: .constant([]))
}

// MARK: - Subviews

struct ModernMedicationTrackingHeaderView: View {
    var body: some View {
        VStack(spacing: CloveSpacing.medium) {
            HStack(spacing: CloveSpacing.small) {
                Text("💊")
                    .font(.system(size: 28))
                    .scaleEffect(1.1)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                Text("Medication Tracking")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [CloveColors.primaryText, CloveColors.primaryText.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text("Mark which medications you've taken today")
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

struct ModernRegularMedicationsCard: View {
    let trackedMedications: [TrackedMedication]
    @Binding var medicationAdherence: [MedicationAdherence]
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.large) {
            Text("Regular Medications")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(CloveColors.primaryText)
            
            VStack(spacing: CloveSpacing.medium) {
                ForEach(trackedMedications, id: \.id) { medication in
                    ModernMedicationChecklistRow(
                        medication: medication,
                        medicationAdherence: $medicationAdherence
                    )
                }
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

struct ModernMedicationChecklistRow: View {
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
        HStack(spacing: CloveSpacing.large) {
            // Medication icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [CloveColors.accent.opacity(0.1), CloveColors.accent.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: medication.isAsNeeded ? "pills.circle" : "pills.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [CloveColors.accent, CloveColors.accent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
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
            
            // Checkmark button
            Button(action: {
                toggleMedication()
            }) {
                ZStack {
                    Circle()
                        .fill((adherence.wrappedValue?.wasTaken ?? false) ? CloveColors.success : Color.clear)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(
                                    (adherence.wrappedValue?.wasTaken ?? false) ? CloveColors.success : CloveColors.secondaryText.opacity(0.5),
                                    lineWidth: 2
                                )
                        )
                        .scaleEffect((adherence.wrappedValue?.wasTaken ?? false) ? 1.1 : 1.0)
                    
                    if adherence.wrappedValue?.wasTaken ?? false {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(ModernCheckButtonStyle())
            .accessibilityLabel("\(medication.name) \((adherence.wrappedValue?.wasTaken ?? false) ? "taken" : "not taken")")
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(
                    (adherence.wrappedValue?.wasTaken ?? false) ?
                    LinearGradient(
                        colors: [CloveColors.success.opacity(0.08), CloveColors.success.opacity(0.03)],
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
                            (adherence.wrappedValue?.wasTaken ?? false) ?
                            CloveColors.success.opacity(0.2) :
                            CloveColors.accent.opacity(0.1),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            toggleMedication()
        }
    }
    
    private func toggleMedication() {
        // Enhanced haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if var currentAdherence = adherence.wrappedValue {
                currentAdherence.wasTaken.toggle()
                adherence.wrappedValue = currentAdherence
            }
        }
    }
}

struct ModernOneTimeMedicationCard: View {
    @Binding var oneTimeMedication: String
    @Binding var showingOneTimeMedication: Bool
    var isOneTimeFocused: FocusState<Bool>.Binding
    @Binding var medicationAdherence: [MedicationAdherence]
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.large) {
            HStack {
                Text("One-Time Medications")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
                
                if !showingOneTimeMedication {
                    Button("Add") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingOneTimeMedication = true
                            isOneTimeFocused.wrappedValue = true
                        }
                    }
                    .font(CloveFonts.body())
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [CloveColors.accent, CloveColors.accent.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: CloveColors.accent.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
                    .buttonStyle(BounceButtonStyle())
                }
            }
            
            // Show one-time medications that were added
            let oneTimeMeds = medicationAdherence.filter { $0.medicationId == -1 }
            if !oneTimeMeds.isEmpty {
                VStack(spacing: CloveSpacing.medium) {
                    ForEach(oneTimeMeds.indices, id: \.self) { index in
                        ModernOneTimeMedicationRow(
                            adherence: $medicationAdherence[medicationAdherence.firstIndex { $0.medicationId == -1 && $0.medicationName == oneTimeMeds[index].medicationName }!],
                            onRemove: {
                                removeOneTimeMedication(oneTimeMeds[index])
                            }
                        )
                    }
                }
            }
            
            // Add new one-time medication input
            if showingOneTimeMedication {
                ModernOneTimeMedicationInput(
                    oneTimeMedication: $oneTimeMedication,
                    isOneTimeFocused: isOneTimeFocused,
                    onAdd: addOneTimeMedication,
                    onCancel: cancelOneTimeMedication
                )
            }
            
            // Empty state for one-time medications
            if oneTimeMeds.isEmpty && !showingOneTimeMedication {
                VStack(spacing: CloveSpacing.medium) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(CloveColors.accent.opacity(0.5))
                    
                    Text("No one-time medications added")
                        .font(CloveFonts.body())
                        .foregroundStyle(CloveColors.secondaryText)
                    
                    Text("Add occasional medications that aren't part of your regular routine")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CloveSpacing.large)
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private func addOneTimeMedication() {
        let trimmed = oneTimeMedication.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let adherence = MedicationAdherence(
            medicationId: -1,
            medicationName: trimmed,
            wasTaken: true,
            isAsNeeded: true
        )
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            medicationAdherence.append(adherence)
            oneTimeMedication = ""
            showingOneTimeMedication = false
            isOneTimeFocused.wrappedValue = false
        }
        
        // Enhanced haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func cancelOneTimeMedication() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            oneTimeMedication = ""
            showingOneTimeMedication = false
            isOneTimeFocused.wrappedValue = false
        }
    }
    
    private func removeOneTimeMedication(_ adherence: MedicationAdherence) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            medicationAdherence.removeAll { $0.medicationId == adherence.medicationId && $0.medicationName == adherence.medicationName }
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

struct ModernOneTimeMedicationInput: View {
    @Binding var oneTimeMedication: String
    var isOneTimeFocused: FocusState<Bool>.Binding
    let onAdd: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: CloveSpacing.medium) {
            HStack(spacing: CloveSpacing.small) {
                Text("💊")
                    .font(.system(size: 16))
                
                Text("Medication Name")
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.primaryText)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            TextField("e.g., Tylenol", text: $oneTimeMedication)
                .focused(isOneTimeFocused)
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
                .onSubmit {
                    onAdd()
                }
            
            HStack(spacing: CloveSpacing.medium) {
                Button("Add") {
                    onAdd()
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
                                colors: oneTimeMedication.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                                [CloveColors.secondaryText, CloveColors.secondaryText.opacity(0.8)] :
                                [CloveColors.success, CloveColors.success.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(
                            color: oneTimeMedication.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                            .clear : CloveColors.success.opacity(0.3),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                )
                .disabled(oneTimeMedication.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(BounceButtonStyle())
                
                Button("Cancel") {
                    onCancel()
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
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(
                    LinearGradient(
                        colors: [CloveColors.accent.opacity(0.05), CloveColors.accent.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(CloveColors.accent.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct ModernOneTimeMedicationRow: View {
    @Binding var adherence: MedicationAdherence
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: CloveSpacing.large) {
            // One-time medication icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [CloveColors.accent.opacity(0.1), CloveColors.accent.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: "pills.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(CloveColors.accent)
            }
            
            // Medication details
            VStack(alignment: .leading, spacing: CloveSpacing.small) {
                HStack {
                    Text(adherence.medicationName)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("One-time")
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
                    
                    Spacer()
                }
            }
            
            // Checkmark and remove buttons
            HStack(spacing: CloveSpacing.small) {
                // Checkmark button
                Button(action: {
                    toggleMedication()
                }) {
                    ZStack {
                        Circle()
                            .fill(adherence.wasTaken ? CloveColors.success : Color.clear)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(
                                        adherence.wasTaken ? CloveColors.success : CloveColors.secondaryText.opacity(0.5),
                                        lineWidth: 2
                                    )
                            )
                            .scaleEffect(adherence.wasTaken ? 1.1 : 1.0)
                        
                        if adherence.wasTaken {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(ModernCheckButtonStyle())
                
                // Remove button
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                .buttonStyle(BounceButtonStyle())
            }
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(
                    adherence.wasTaken ?
                    LinearGradient(
                        colors: [CloveColors.success.opacity(0.08), CloveColors.success.opacity(0.03)],
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
                            adherence.wasTaken ?
                            CloveColors.success.opacity(0.2) :
                            CloveColors.accent.opacity(0.1),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            toggleMedication()
        }
    }
    
    private func toggleMedication() {
        // Enhanced haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            adherence.wasTaken.toggle()
        }
    }
}

struct ModernMedicationEmptyChecklistCard: View {
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
                Text("No medications to track")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Text("Add regular medications in Settings, or add a one-time medication above")
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CloveSpacing.xlarge)
        .padding(.horizontal, CloveSpacing.large)
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

struct ModernCheckButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
