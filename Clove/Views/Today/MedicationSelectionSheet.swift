import SwiftUI

struct MedicationSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var medicationAdherence: [MedicationAdherence]
    
    @State private var trackedMedications: [TrackedMedication] = []
    @State private var oneTimeMedication = ""
    @State private var showingOneTimeMedication = false
    @FocusState private var isOneTimeFocused: Bool
    
    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var regularMedsOpacity: Double = 0
    @State private var oneTimeMedsOpacity: Double = 0
    @State private var emptyStateOpacity: Double = 0
    @State private var headerOffset: CGFloat = -20
    @State private var regularMedsOffset: CGFloat = 30
    @State private var oneTimeMedsOffset: CGFloat = 30
    @State private var emptyStateOffset: CGFloat = 30
    @State private var medicationRowsVisible: [Bool] = []
    
    private let medicationRepo = MedicationRepository.shared
    
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
                        // Modern Header
                        ModernMedicationTrackingHeaderView()
                            .opacity(headerOpacity)
                            .offset(y: headerOffset)
                        
                        // Regular medications checklist
                        if !trackedMedications.isEmpty {
                            ModernRegularMedicationsCard(
                                trackedMedications: trackedMedications,
                                medicationAdherence: $medicationAdherence,
                                medicationRowsVisible: $medicationRowsVisible
                            )
                            .opacity(regularMedsOpacity)
                            .offset(y: regularMedsOffset)
                        }
                        
                        // One-time medication section
                        ModernOneTimeMedicationCard(
                            oneTimeMedication: $oneTimeMedication,
                            showingOneTimeMedication: $showingOneTimeMedication,
                            isOneTimeFocused: $isOneTimeFocused,
                            medicationAdherence: $medicationAdherence
                        )
                        .opacity(oneTimeMedsOpacity)
                        .offset(y: oneTimeMedsOffset)
                        
                        // Empty state
                        if trackedMedications.isEmpty && medicationAdherence.isEmpty {
                            ModernMedicationEmptyChecklistCard()
                                .opacity(emptyStateOpacity)
                                .offset(y: emptyStateOffset)
                        }
                        
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
            syncMedicationAdherence()
            startEntranceAnimations()
        }
    }
    
    private func startEntranceAnimations() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            headerOpacity = 1.0
            headerOffset = 0
        }
        
        if !trackedMedications.isEmpty {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                regularMedsOpacity = 1.0
                regularMedsOffset = 0
            }
            
            // Animate medication rows individually
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                for i in 0..<medicationRowsVisible.count {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(i) * 0.1)) {
                        medicationRowsVisible[i] = true
                    }
                }
            }
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
            oneTimeMedsOpacity = 1.0
            oneTimeMedsOffset = 0
        }
        
        if trackedMedications.isEmpty && medicationAdherence.isEmpty {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
                emptyStateOpacity = 1.0
                emptyStateOffset = 0
            }
        }
    }
    
    private func loadMedications() {
        trackedMedications = medicationRepo.getTrackedMedications()
        medicationRowsVisible = Array(repeating: false, count: trackedMedications.count)
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

// MARK: - Modern Views

struct ModernMedicationTrackingHeaderView: View {
    var body: some View {
        VStack(spacing: CloveSpacing.medium) {
            // Icon and title
            HStack(spacing: CloveSpacing.medium) {
                ZStack {
                    Circle()
                        .fill(Theme.shared.accent.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Theme.shared.accent)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Medication Tracking")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("Mark today's medications")
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

struct ModernRegularMedicationsCard: View {
    let trackedMedications: [TrackedMedication]
    @Binding var medicationAdherence: [MedicationAdherence]
    @Binding var medicationRowsVisible: [Bool]
    
    private var completionProgress: Double {
        let totalMedications = trackedMedications.count
        guard totalMedications > 0 else { return 0.0 }
        
        let takenMedications = medicationAdherence.filter { adherence in
            adherence.wasTaken && trackedMedications.contains { $0.id == adherence.medicationId }
        }.count
        
        return Double(takenMedications) / Double(totalMedications)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.large) {
            // Section header with progress
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Regular Medications")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("\(Int(completionProgress * 100))% completed")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
                
                // Progress circle
                ZStack {
                    Circle()
                        .stroke(Theme.shared.accent.opacity(0.2), lineWidth: 4)
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .trim(from: 0, to: completionProgress)
                        .stroke(Theme.shared.accent, lineWidth: 4)
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: completionProgress)
                    
                    Text("\(Int(completionProgress * 100))%")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.shared.accent)
                }
            }
            
            VStack(spacing: CloveSpacing.medium) {
                ForEach(Array(trackedMedications.enumerated()), id: \.element.id) { index, medication in
                    ModernMedicationChecklistRow(
                        medication: medication,
                        medicationAdherence: $medicationAdherence
                    )
                    .opacity(medicationRowsVisible.indices.contains(index) ? (medicationRowsVisible[index] ? 1.0 : 0) : 0)
                    .scaleEffect(medicationRowsVisible.indices.contains(index) ? (medicationRowsVisible[index] ? 1.0 : 0.8) : 0.8)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: medicationRowsVisible.indices.contains(index) ? medicationRowsVisible[index] : false)
                }
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
        HStack(spacing: CloveSpacing.medium) {
            // Medication icon
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
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Theme.shared.accent.opacity(0.1))
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
            
            // Checkmark button
            Button(action: {
                toggleMedication()
            }) {
                ZStack {
                    Circle()
                        .fill((adherence.wrappedValue?.wasTaken ?? false) ? CloveColors.success : CloveColors.background)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(
                                    (adherence.wrappedValue?.wasTaken ?? false) ? CloveColors.success : CloveColors.secondaryText.opacity(0.3),
                                    lineWidth: 2
                                )
                        )
                        .scaleEffect((adherence.wrappedValue?.wasTaken ?? false) ? 1.1 : 1.0)
                        .shadow(
                            color: (adherence.wrappedValue?.wasTaken ?? false) ? CloveColors.success.opacity(0.3) : .clear,
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                    
                    if adherence.wrappedValue?.wasTaken ?? false {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .scaleEffect(1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: adherence.wrappedValue?.wasTaken)
                    }
                }
            }
            .buttonStyle(ModernCheckButtonStyle())
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
                        colors: [CloveColors.background, CloveColors.background],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(
                            (adherence.wrappedValue?.wasTaken ?? false) ?
                            CloveColors.success.opacity(0.3) :
                            CloveColors.secondaryText.opacity(0.1),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: (adherence.wrappedValue?.wasTaken ?? false) ? CloveColors.success.opacity(0.1) : .black.opacity(0.03),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            toggleMedication()
        }
    }
    
    private func toggleMedication() {
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("One-Time Medications")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("Occasional medications")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
                
                if !showingOneTimeMedication {
                    Button("Add") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingOneTimeMedication = true
                            isOneTimeFocused.wrappedValue = true
                        }
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Theme.shared.accent)
                            .shadow(color: Theme.shared.accent.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
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
                    ZStack {
                        Circle()
                            .fill(Theme.shared.accent.opacity(0.1))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "plus.circle")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(Theme.shared.accent.opacity(0.6))
                    }
                    
                    Text("No one-time medications")
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("Add occasional medications not in your routine")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CloveSpacing.large)
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
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
            VStack(alignment: .leading, spacing: CloveSpacing.small) {
                Text("Medication Name")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(CloveColors.secondaryText)
                
                TextField("e.g., Tylenol", text: $oneTimeMedication)
                    .font(.system(.body, design: .rounded))
                    .focused(isOneTimeFocused)
                    .padding(CloveSpacing.medium)
                    .background(
                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                            .fill(CloveColors.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: CloveCorners.medium)
                                    .stroke(
                                        isOneTimeFocused.wrappedValue ? Theme.shared.accent.opacity(0.5) : CloveColors.secondaryText.opacity(0.2),
                                        lineWidth: 1.5
                                    )
                            )
                    )
                    .onSubmit {
                        if !oneTimeMedication.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onAdd()
                        }
                    }
            }
            
            HStack(spacing: CloveSpacing.medium) {
                Button("Add") {
                    onAdd()
                }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .fill(
                            oneTimeMedication.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                            CloveColors.secondaryText.opacity(0.5) : CloveColors.success
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
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: oneTimeMedication.isEmpty)
                
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
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(
                    LinearGradient(
                        colors: [Theme.shared.accent.opacity(0.05), Theme.shared.accent.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(Theme.shared.accent.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct ModernOneTimeMedicationRow: View {
    @Binding var adherence: MedicationAdherence
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: CloveSpacing.medium) {
            // One-time medication icon
            ZStack {
                Circle()
                    .fill(Theme.shared.accent.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "pills.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.shared.accent)
            }
            
            // Medication details
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(adherence.medicationName)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("One-time")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.shared.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Theme.shared.accent.opacity(0.1))
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
                            .fill(adherence.wasTaken ? CloveColors.success : CloveColors.background)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(
                                        adherence.wasTaken ? CloveColors.success : CloveColors.secondaryText.opacity(0.3),
                                        lineWidth: 2
                                    )
                            )
                            .scaleEffect(adherence.wasTaken ? 1.1 : 1.0)
                            .shadow(
                                color: adherence.wasTaken ? CloveColors.success.opacity(0.3) : .clear,
                                radius: 4,
                                x: 0,
                                y: 2
                            )
                        
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
                        .font(.system(size: 18))
                        .foregroundStyle(CloveColors.secondaryText.opacity(0.6))
                }
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
                        colors: [CloveColors.background, CloveColors.background],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(
                            adherence.wasTaken ?
                            CloveColors.success.opacity(0.3) :
                            CloveColors.secondaryText.opacity(0.1),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: adherence.wasTaken ? CloveColors.success.opacity(0.1) : .black.opacity(0.03),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            toggleMedication()
        }
    }
    
    private func toggleMedication() {
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
            ZStack {
                Circle()
                    .fill(Theme.shared.accent.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "pills")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Theme.shared.accent.opacity(0.6))
            }
            
            VStack(spacing: CloveSpacing.small) {
                Text("No medications to track")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Text("Add regular medications in Settings, or add a one-time medication above")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(CloveColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CloveSpacing.xlarge)
        .padding(.horizontal, CloveSpacing.large)
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

struct ModernCheckButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

#Preview {
    MedicationSelectionSheet(medicationAdherence: .constant([]))
}
