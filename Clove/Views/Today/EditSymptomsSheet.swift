import SwiftUI

struct EditSymptomsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var newSymptomName = ""
    @State private var editingSymptom: TrackedSymptom? = nil
    @State private var editingName = ""
    @FocusState private var isTextFieldFocused: Bool
    
    let viewModel: TodayViewModel
    let trackedSymptoms: [TrackedSymptom]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Clear background for floating sheet effect
                Color.clear
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: CloveSpacing.medium) {
                        Text("Edit Symptoms")
                            .font(CloveFonts.title())
                            .foregroundStyle(CloveColors.primaryText)
                        
                        Text("Add new symptoms to track or edit existing ones")
                            .font(CloveFonts.body())
                            .foregroundStyle(CloveColors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, CloveSpacing.large)
                    .padding(.top, CloveSpacing.large)
                    
                    // Add new symptom section
                    VStack(alignment: .leading, spacing: CloveSpacing.small) {
                        Text("Add New Symptom")
                            .font(CloveFonts.sectionTitle())
                            .foregroundStyle(CloveColors.primaryText)
                            .padding(.horizontal, CloveSpacing.large)
                        
                        HStack(spacing: CloveSpacing.medium) {
                            TextField("Enter symptom name", text: $newSymptomName)
                                .textFieldStyle(.roundedBorder)
                                .focused($isTextFieldFocused)
                                .onSubmit {
                                    addSymptom()
                                }
                            
                            Button(action: addSymptom) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Theme.shared.accent)
                            }
                            .disabled(newSymptomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(newSymptomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                        }
                        .padding(.horizontal, CloveSpacing.large)
                    }
                    .padding(.top, CloveSpacing.xlarge)
                    
                    // Current symptoms list
                    VStack(alignment: .leading, spacing: CloveSpacing.small) {
                        Text("Current Symptoms")
                            .font(CloveFonts.sectionTitle())
                            .foregroundStyle(CloveColors.primaryText)
                            .padding(.horizontal, CloveSpacing.large)
                        
                        if trackedSymptoms.isEmpty {
                            VStack(spacing: CloveSpacing.medium) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 40))
                                    .foregroundStyle(CloveColors.secondaryText.opacity(0.5))
                                
                                Text("No symptoms added yet")
                                    .font(CloveFonts.body())
                                    .foregroundStyle(CloveColors.secondaryText)
                                
                                Text("Add your first symptom above to get started")
                                    .font(CloveFonts.small())
                                    .foregroundStyle(CloveColors.secondaryText.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, CloveSpacing.xlarge)
                        } else {
                            List {
                                ForEach(trackedSymptoms, id: \.id) { symptom in
                                    SymptomRowView(
                                        symptom: symptom,
                                        isEditing: editingSymptom?.id == symptom.id,
                                        editingName: $editingName,
                                        onEdit: { startEditing(symptom) },
                                        onSave: { saveEdit() },
                                        onCancel: { cancelEdit() }
                                    )
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                }
                                .onDelete(perform: deleteSymptoms)
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                        }
                    }
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
                    .foregroundStyle(Theme.shared.accent)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationBackground(.thinMaterial)
        .presentationCornerRadius(20)
    }
    
    private func addSymptom() {
        let trimmedName = newSymptomName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        viewModel.addSymptom(name: trimmedName)
        newSymptomName = ""
        isTextFieldFocused = false
    }
    
    private func startEditing(_ symptom: TrackedSymptom) {
        editingSymptom = symptom
        editingName = symptom.name
    }
    
    private func saveEdit() {
        guard let symptom = editingSymptom else { return }
        viewModel.updateSymptom(id: symptom.id ?? 0, newName: editingName)
        cancelEdit()
    }
    
    private func cancelEdit() {
        editingSymptom = nil
        editingName = ""
    }
    
    private func deleteSymptoms(at offsets: IndexSet) {
        for index in offsets {
            let symptom = trackedSymptoms[index]
            if let id = symptom.id {
                viewModel.deleteSymptom(id: id)
            }
        }
    }
}

struct SymptomRowView: View {
    let symptom: TrackedSymptom
    let isEditing: Bool
    @Binding var editingName: String
    let onEdit: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: CloveSpacing.medium) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(Theme.shared.accent)
            
            if isEditing {
                TextField("Symptom name", text: $editingName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        onSave()
                    }
                
                Button("Save") {
                    onSave()
                }
                .font(CloveFonts.small())
                .foregroundStyle(Theme.shared.accent)
                .fontWeight(.semibold)
                
                Button("Cancel") {
                    onCancel()
                }
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)
            } else {
                Text(symptom.name)
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
                
                Button("Edit") {
                    onEdit()
                }
                .font(CloveFonts.small())
                .foregroundStyle(Theme.shared.accent)
                .fontWeight(.semibold)
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

#Preview {
    EditSymptomsSheet(
        viewModel: TodayViewModel(settings: .default),
        trackedSymptoms: [
            TrackedSymptom(id: 1, name: "Headache"),
            TrackedSymptom(id: 2, name: "Fatigue"),
            TrackedSymptom(id: 3, name: "Joint Pain")
        ]
    )
}
