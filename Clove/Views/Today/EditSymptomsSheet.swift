import SwiftUI

struct EditSymptomsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var newSymptomName = ""
    @State private var newSymptomIsBinary = false
    @State private var editingSymptom: TrackedSymptom? = nil
    @State private var editingName = ""
    @State private var editingIsBinary = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var isLoading = false
    @State private var isShowingAddForm = false
    
    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var formOpacity: Double = 0
    @State private var listOpacity: Double = 0
    @State private var headerOffset: CGFloat = -20
    @State private var formOffset: CGFloat = 30
    @State private var listOffset: CGFloat = 30
    
    @State var trackedSymptoms: [TrackedSymptom]
    var hideCancel: Bool = false
    var onDone: () -> Void = {}
    var refresh: () -> Void = {}
    
    var body: some View {
        NavigationStack {
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
                    VStack(spacing: CloveSpacing.large) {
                        ModernSymptomHeaderView()
                            .opacity(headerOpacity)
                            .offset(y: headerOffset)
                        
                        // Symptoms list
                        ModernSymptomListView(
                            trackedSymptoms: $trackedSymptoms,
                            editingSymptom: editingSymptom,
                            editingName: $editingName,
                            editingIsBinary: $editingIsBinary,
                            onEdit: startEditing,
                            onSave: saveEdit,
                            onCancel: cancelEdit,
                            onDelete: deleteSymptoms,
                            onReorder: persistSymptomOrder
                        )
                        .opacity(listOpacity)
                        .offset(y: listOffset)

                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                isShowingAddForm.toggle()
                            }
                            if isShowingAddForm { isTextFieldFocused = true }
                        } label: {
                            Label(
                                isShowingAddForm ? "Hide New Symptom Form" : "Add Tracked Symptom",
                                systemImage: isShowingAddForm ? "chevron.up" : "plus.circle.fill"
                            )
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.shared.accent)

                        if isShowingAddForm {
                            ModernAddSymptomFormView(
                                newSymptomName: $newSymptomName,
                                newSymptomIsBinary: $newSymptomIsBinary,
                                isTextFieldFocused: $isTextFieldFocused,
                                isLoading: $isLoading,
                                isAddButtonEnabled: isAddButtonEnabled,
                                onAddSymptom: addSymptom
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        Spacer(minLength: CloveSpacing.xlarge)
                    }
                    .padding(.horizontal, CloveSpacing.large)
                    .padding(.top, CloveSpacing.medium)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if (!hideCancel) {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundStyle(CloveColors.secondaryText)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dismiss()
                        }
                        onDone()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationBackground(.thinMaterial)
        .presentationCornerRadius(20)
        .onAppear {
            startEntranceAnimations()
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
    }
    
    private var isAddButtonEnabled: Bool {
        !newSymptomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func addSymptom() {
        let trimmedName = newSymptomName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isLoading = true
        }

        SymptomManager.shared.addSymptom(name: trimmedName, isBinary: newSymptomIsBinary) {
            self.refresh()
            self.trackedSymptoms = SymptomManager.shared.fetchSymptoms()
        }

        // Enhanced haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
            // Clear form
            newSymptomName = ""
            newSymptomIsBinary = false
            isTextFieldFocused = false
            isLoading = false
            isShowingAddForm = false
        }
    }
    
    private func startEditing(_ symptom: TrackedSymptom) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            editingSymptom = symptom
            editingName = symptom.name
            editingIsBinary = symptom.isBinary
        }
    }
    
    private func saveEdit() {
        guard let symptom = editingSymptom, let id = symptom.id else { return }

        let trimmedName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        SymptomManager.shared.updateSymptom(id: id, newName: trimmedName, isBinary: editingIsBinary) {
            self.refresh()
            self.trackedSymptoms = SymptomManager.shared.fetchSymptoms()
        }

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        cancelEdit()
    }

    private func cancelEdit() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            editingSymptom = nil
            editingName = ""
            editingIsBinary = false
        }
    }
    
    private func deleteSymptoms(at offsets: IndexSet) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            for index in offsets {
                let symptom = trackedSymptoms[index]
                if let id = symptom.id {
                    SymptomManager.shared.deleteSymptom(id: id) {
                        self.refresh()
                        self.trackedSymptoms = SymptomManager.shared.fetchSymptoms()
                    }
                    
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
            }
        }
    }

    private func persistSymptomOrder(_ symptoms: [TrackedSymptom]) -> Bool {
        let success = SymptomsRepo.shared.reorderSymptoms(symptoms)
        if success {
            refresh()
            UISelectionFeedbackGenerator().selectionChanged()
        } else {
            ToastManager.shared.showToast(
                message: "Could not save symptom order",
                color: CloveColors.error,
                icon: Image(systemName: "exclamationmark.triangle")
            )
        }
        return success
    }
}

// MARK: - Modern Views

struct ModernSymptomHeaderView: View {
    var body: some View {
        HStack(alignment: .top, spacing: CloveSpacing.medium) {
            Image(systemName: "bandage.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.shared.accent)
                .frame(width: 42, height: 42)
                .background(Theme.shared.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                Text("Tracked Symptoms")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(CloveColors.primaryText)

                Text("Press and drag the grip to choose how symptoms appear throughout Clove.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(CloveColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, CloveSpacing.small)
    }
}

struct ModernAddSymptomFormView: View {
    @Binding var newSymptomName: String
    @Binding var newSymptomIsBinary: Bool
    var isTextFieldFocused: FocusState<Bool>.Binding
    @Binding var isLoading: Bool
    let isAddButtonEnabled: Bool
    let onAddSymptom: () -> Void

    private let quickSymptoms = ["Headache", "Fatigue", "Nausea", "Bloating"]
    @State private var quickButtonsVisible = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.large) {
            // Section header
            HStack {
                Text("New Tracked Symptom")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
            }
            
            VStack(spacing: CloveSpacing.large) {
                // Input field
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    Text("Symptom Name")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)

                    TextField("e.g., Headache, Fatigue", text: $newSymptomName)
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
                        .onSubmit {
                            if isAddButtonEnabled {
                                onAddSymptom()
                            }
                        }
                }

                // Symptom type toggle
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    Text("Rating Scale")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)

                    HStack(spacing: CloveSpacing.small) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                newSymptomIsBinary = false
                            }
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }) {
                            HStack(spacing: CloveSpacing.small) {
                                Text("0-10")
                                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(!newSymptomIsBinary ? .white : CloveColors.primaryText)
                            .background(
                                RoundedRectangle(cornerRadius: CloveCorners.medium)
                                    .fill(!newSymptomIsBinary ? Theme.shared.accent : CloveColors.background)
                            )
                        }

                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                newSymptomIsBinary = true
                            }
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }) {
                            HStack(spacing: CloveSpacing.small) {
                                Text("Yes/No")
                                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(newSymptomIsBinary ? .white : CloveColors.primaryText)
                            .background(
                                RoundedRectangle(cornerRadius: CloveCorners.medium)
                                    .fill(newSymptomIsBinary ? Theme.shared.accent : CloveColors.background)
                            )
                        }
                    }
                    
                    Text(newSymptomIsBinary ? "Log a 'Yes' or 'No' response each day" : "Symptom will be rated on a 0-10 scale each day")
                        .font(.caption)
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                // Quick select buttons
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    Text("Quick Add")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: CloveSpacing.small) {
                        ForEach(Array(quickSymptoms.enumerated()), id: \.offset) { index, symptom in
                            Button(symptom) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    newSymptomName = symptom
                                }
                                
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(newSymptomName == symptom ? .white : Theme.shared.accent)
                            .padding(.horizontal, CloveSpacing.medium)
                            .padding(.vertical, CloveSpacing.small)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: CloveCorners.medium)
                                    .fill(newSymptomName == symptom ? Theme.shared.accent : Theme.shared.accent.opacity(0.1))
                            )
                            .scaleEffect(quickButtonsVisible ? 1.0 : 0.8)
                            .opacity(quickButtonsVisible ? 1.0 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.1), value: quickButtonsVisible)
                        }
                    }
                }
                
                // Add button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        onAddSymptom()
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
                        
                        Text(isLoading ? "Adding..." : "Add to Daily Tracker")
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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                quickButtonsVisible = true
            }
        }
    }
}

struct ModernSymptomListView: View {
    @Binding var trackedSymptoms: [TrackedSymptom]
    let editingSymptom: TrackedSymptom?
    @Binding var editingName: String
    @Binding var editingIsBinary: Bool
    let onEdit: (TrackedSymptom) -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let onDelete: (IndexSet) -> Void
    let onReorder: ([TrackedSymptom]) -> Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.large) {
            // Section header
            HStack {
                Text("Your Symptoms")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
                
                if !trackedSymptoms.isEmpty {
                    Text("\(trackedSymptoms.count)")
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
            
            if trackedSymptoms.isEmpty {
                ModernSymptomEmptyStateView()
            } else {
                VStack(spacing: CloveSpacing.medium) {
                    ForEach(Array(trackedSymptoms.enumerated()), id: \.element.id) { index, symptom in
                        ModernSymptomCard(
                            symptom: symptom,
                            isEditing: editingSymptom?.id == symptom.id,
                            dragIdentifier: String(symptom.id ?? 0),
                            editingName: $editingName,
                            editingIsBinary: $editingIsBinary,
                            onEdit: { onEdit(symptom) },
                            onSave: onSave,
                            onCancel: onCancel,
                            onDelete: {
                                if let index = trackedSymptoms.firstIndex(where: { $0.id == symptom.id }) {
                                    onDelete(IndexSet(integer: index))
                                }
                            }
                        )
                        .dropDestination(for: String.self) { identifiers, _ in
                            guard let rawID = identifiers.first,
                                  let sourceID = Int64(rawID),
                                  let targetID = symptom.id else { return false }
                            return move(sourceID: sourceID, before: targetID)
                        }
                    }
                }
            }
        }
    }

    private func move(sourceID: Int64, before targetID: Int64) -> Bool {
        guard sourceID != targetID,
              let source = trackedSymptoms.firstIndex(where: { $0.id == sourceID }),
              let originalTarget = trackedSymptoms.firstIndex(where: { $0.id == targetID }) else { return false }
        let isMovingDown = source < originalTarget
        var reordered = trackedSymptoms
        let moved = reordered.remove(at: source)
        guard let destination = reordered.firstIndex(where: { $0.id == targetID }) else { return false }
        reordered.insert(moved, at: isMovingDown ? destination + 1 : destination)
        return save(reordered)
    }

    @discardableResult
    private func save(_ symptoms: [TrackedSymptom]) -> Bool {
        let ordered = symptoms.enumerated().map { index, symptom in
            var updated = symptom
            updated.displayOrder = index
            return updated
        }
        guard onReorder(ordered) else { return false }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            trackedSymptoms = ordered
        }
        return true
    }
}

struct ModernSymptomCard: View {
    let symptom: TrackedSymptom
    let isEditing: Bool
    let dragIdentifier: String
    @Binding var editingName: String
    @Binding var editingIsBinary: Bool
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
                        Text("Edit Symptom")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(CloveColors.primaryText)
                        Spacer()
                    }
                    
                    TextField("Symptom name", text: $editingName)
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

                    // Symptom type toggle
                    HStack(spacing: CloveSpacing.small) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                editingIsBinary = false
                            }
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }) {
                            Text("0-10")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .foregroundStyle(!editingIsBinary ? .white : CloveColors.primaryText)
                                .background(
                                    RoundedRectangle(cornerRadius: CloveCorners.small)
                                        .fill(!editingIsBinary ? Theme.shared.accent : CloveColors.background)
                                )
                        }

                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                editingIsBinary = true
                            }
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }) {
                            Text("Yes/No")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .foregroundStyle(editingIsBinary ? .white : CloveColors.primaryText)
                                .background(
                                    RoundedRectangle(cornerRadius: CloveCorners.small)
                                        .fill(editingIsBinary ? Theme.shared.accent : CloveColors.background)
                                )
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
                HStack(spacing: 12) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.shared.accent)
                        .frame(width: 42, height: 48)
                        .background(Theme.shared.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle())
                        .draggable(dragIdentifier) {
                            HStack(spacing: 10) {
                                Image(systemName: "line.3.horizontal")
                                Text(symptom.name)
                                    .lineLimit(1)
                            }
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(CloveColors.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(CloveColors.card, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .accessibilityLabel("Drag to reorder \(symptom.name)")
                    
                    // Name
                    VStack(alignment: .leading, spacing: 2) {
                        Text(symptom.name)
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(CloveColors.primaryText)
                        
                        Text(symptom.isBinary ? "Present / absent" : "Severity 0–10")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button("Edit Symptom", systemImage: "pencil", action: onEdit)
                        Button("Delete Symptom", systemImage: "trash", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(CloveColors.secondaryText)
                            .frame(width: 40, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Actions for \(symptom.name)")
                }
            }
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.large)
                        .stroke(
                            isEditing ? Theme.shared.accent.opacity(0.35) : CloveColors.secondaryText.opacity(0.12),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isEditing)
    }
}

struct ModernSymptomEmptyStateView: View {
    var body: some View {
        VStack(spacing: CloveSpacing.large) {
            ZStack {
                Circle()
                    .fill(Theme.shared.accent.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "bandage")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Theme.shared.accent.opacity(0.6))
            }
            
            VStack(spacing: CloveSpacing.small) {
                Text("No symptoms yet")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Text("Add symptoms you want available in your daily tracker.")
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
    EditSymptomsSheet(
        trackedSymptoms: [
            TrackedSymptom(id: 1, name: "Headache"),
            TrackedSymptom(id: 2, name: "Fatigue"),
            TrackedSymptom(id: 3, name: "Joint Pain")
        ]
    )
}
