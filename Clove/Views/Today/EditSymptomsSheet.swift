import SwiftUI

struct EditSymptomsSheet: View {
   @Environment(\.dismiss) private var dismiss
   @State private var newSymptomName = ""
   @State private var editingSymptom: TrackedSymptom? = nil
   @State private var editingName = ""
   @FocusState private var isTextFieldFocused: Bool
   @State private var isLoading = false
   
   @State var trackedSymptoms: [TrackedSymptom]
   var hideCancel: Bool = false
   var onDone: () -> Void = {}
   var refresh: () -> Void = {}
   
   var body: some View {
      NavigationView {
         ZStack {
            // Gradient background
            LinearGradient(
               colors: [Theme.shared.accent.opacity(0.03), Color.clear],
               startPoint: .topLeading,
               endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
               VStack(spacing: CloveSpacing.large) {
                  // Header with gradient background
                  ModernSymptomHeaderView()
                  
                  // Add new symptom section
                  ModernAddSymptomFormView(
                     newSymptomName: $newSymptomName,
                     isTextFieldFocused: $isTextFieldFocused,
                     isLoading: $isLoading,
                     isAddButtonEnabled: isAddButtonEnabled,
                     onAddSymptom: addSymptom
                  )
                  
                  // Current symptoms list
                  ModernSymptomListView(
                     trackedSymptoms: trackedSymptoms,
                     editingSymptom: editingSymptom,
                     editingName: $editingName,
                     onEdit: startEditing,
                     onSave: saveEdit,
                     onCancel: cancelEdit,
                     onDelete: deleteSymptoms
                  )
                  
                  Spacer(minLength: CloveSpacing.xlarge)
               }
               .padding(.horizontal, CloveSpacing.large)
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
               Button {
                  withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                     dismiss()
                  }
                  onDone()
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
      
      SymptomManager.shared.addSymptom(name: trimmedName) {
         self.refresh()
         self.trackedSymptoms = SymptomManager.shared.fetchSymptoms()
      }
      
      // Enhanced haptic feedback
      let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
      impactFeedback.impactOccurred()
      
      withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
         // Clear form
         newSymptomName = ""
         isTextFieldFocused = false
         isLoading = false
      }
   }
   
   private func startEditing(_ symptom: TrackedSymptom) {
      editingSymptom = symptom
      editingName = symptom.name
   }
   
   private func saveEdit() {
      guard let symptom = editingSymptom, let id = symptom.id else { return }
      
      let trimmedName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedName.isEmpty else { return }
      
      SymptomManager.shared.updateSymptom(id: id, newName: trimmedName) {
         self.refresh()
         self.trackedSymptoms = SymptomManager.shared.fetchSymptoms()
      }
      
      // Haptic feedback
      let impactFeedback = UIImpactFeedbackGenerator(style: .light)
      impactFeedback.impactOccurred()
      
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

// MARK: - Modern Views

struct ModernSymptomHeaderView: View {
   var body: some View {
      VStack(spacing: CloveSpacing.medium) {
         HStack(spacing: CloveSpacing.small) {
            Text("🩹")
               .font(.system(size: 28))
               .scaleEffect(1.1)
               .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            Text("Manage Symptoms")
               .font(.system(.title, design: .rounded).weight(.bold))
               .foregroundStyle(
                  LinearGradient(
                     colors: [CloveColors.primaryText, CloveColors.primaryText.opacity(0.8)],
                     startPoint: .topLeading,
                     endPoint: .bottomTrailing
                  )
               )
         }
         
         Text("Track your symptoms to identify patterns and triggers")
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
                  colors: [Theme.shared.accent.opacity(0.08), Theme.shared.accent.opacity(0.03)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
               )
            )
            .overlay(
               RoundedRectangle(cornerRadius: CloveCorners.medium)
                  .stroke(
                     LinearGradient(
                        colors: [Theme.shared.accent.opacity(0.2), Theme.shared.accent.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                     ),
                     lineWidth: 1
                  )
            )
            .shadow(color: Theme.shared.accent.opacity(0.1), radius: 8, x: 0, y: 4)
      )
   }
}

struct ModernAddSymptomFormView: View {
   @Binding var newSymptomName: String
   var isTextFieldFocused: FocusState<Bool>.Binding
   @Binding var isLoading: Bool
   let isAddButtonEnabled: Bool
   let onAddSymptom: () -> Void
   
   private let quickSymptoms = ["Headache", "Fatigue", "Nausea", "Bloating"]
   
   var body: some View {
      VStack(alignment: .leading, spacing: CloveSpacing.large) {
         Text("Add New Symptom")
            .font(.system(.title2, design: .rounded).weight(.bold))
            .foregroundStyle(CloveColors.primaryText)
         
         VStack(spacing: CloveSpacing.large) {
            // Symptom name with icon
            SymptomInputField(
               icon: "🩹",
               title: "Symptom Name",
               placeholder: "e.g., Headache",
               text: $newSymptomName,
               isRequired: true,
               isTextFieldFocused: isTextFieldFocused,
               onSubmit: onAddSymptom
            )
            
            // Quick-select symptom buttons
            VStack(alignment: .leading, spacing: CloveSpacing.small) {
               HStack(spacing: CloveSpacing.small) {
                  Text("⚡")
                     .font(.system(size: 16))
                  
                  Text("Quick Add")
                     .font(CloveFonts.body())
                     .foregroundStyle(CloveColors.primaryText)
                     .fontWeight(.medium)
               }
               
               ScrollView(.horizontal) {
                  HStack(spacing: CloveSpacing.small) {
                     ForEach(quickSymptoms, id: \.self) { symptom in
                        Button(symptom) {
                           withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                              newSymptomName = symptom
                           }
                           
                           // Haptic feedback
                           let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                           impactFeedback.impactOccurred()
                        }
                        .font(CloveFonts.small())
                        .foregroundStyle(newSymptomName == symptom ? .white : Theme.shared.accent)
                        .padding(.horizontal, CloveSpacing.small)
                        .padding(.vertical, CloveSpacing.xsmall)
                        .background(
                           RoundedRectangle(cornerRadius: CloveCorners.small)
                              .fill(newSymptomName == symptom ? Theme.shared.accent : Theme.shared.accent.opacity(0.1))
                        )
                        .scaleEffect(newSymptomName == symptom ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: newSymptomName)
                     }
                     
                     Spacer()
                  }
               }
               .scrollIndicators(.hidden)
            }
            
            // Add button with gradient and animation
            SymptomAddButton(
               title: "Add Symptom",
               isEnabled: isAddButtonEnabled,
               isLoading: isLoading,
               action: onAddSymptom
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

struct ModernSymptomListView: View {
   let trackedSymptoms: [TrackedSymptom]
   let editingSymptom: TrackedSymptom?
   @Binding var editingName: String
   let onEdit: (TrackedSymptom) -> Void
   let onSave: () -> Void
   let onCancel: () -> Void
   let onDelete: (IndexSet) -> Void
   
   var body: some View {
      VStack(alignment: .leading, spacing: CloveSpacing.large) {
         Text("Current Symptoms")
            .font(.system(.title2, design: .rounded).weight(.bold))
            .foregroundStyle(CloveColors.primaryText)
         
         if trackedSymptoms.isEmpty {
            ModernSymptomEmptyStateView()
         } else {
            VStack(spacing: CloveSpacing.medium) {
               ForEach(trackedSymptoms, id: \.id) { symptom in
                  ModernSymptomCard(
                     symptom: symptom,
                     isEditing: editingSymptom?.id == symptom.id,
                     editingName: $editingName,
                     onEdit: { onEdit(symptom) },
                     onSave: onSave,
                     onCancel: onCancel,
                     onDelete: {
                        if let index = trackedSymptoms.firstIndex(where: { $0.id == symptom.id }) {
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

struct ModernSymptomCard: View {
   let symptom: TrackedSymptom
   let isEditing: Bool
   @Binding var editingName: String
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
                  Image(systemName: "bandage.fill")
                     .font(.system(size: 20))
                     .foregroundStyle(
                        LinearGradient(
                           colors: [Theme.shared.accent, Theme.shared.accent.opacity(0.7)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing
                        )
                     )
                     .frame(width: 32, height: 32)
                     .background(
                        Circle()
                           .fill(Theme.shared.accent.opacity(0.1))
                     )
                  
                  Text("Edit Symptom")
                     .font(.system(.body, design: .rounded).weight(.semibold))
                     .foregroundStyle(CloveColors.primaryText)
                  
                  Spacer()
               }
               
               // Edit field
               SymptomEditField(placeholder: "Symptom name", text: $editingName)
               
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
               // Symptom icon
               Image(systemName: "bandage.fill")
                  .font(.system(size: 20))
                  .foregroundStyle(
                     LinearGradient(
                        colors: [Theme.shared.accent, Theme.shared.accent.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                     )
                  )
                  .frame(width: 32, height: 32)
                  .background(
                     Circle()
                        .fill(Theme.shared.accent.opacity(0.1))
                  )
               
               // Symptom details
               VStack(alignment: .leading, spacing: CloveSpacing.small) {
                  Text(symptom.name)
                     .font(.system(.body, design: .rounded).weight(.semibold))
                     .foregroundStyle(CloveColors.primaryText)
                  
                  Spacer()
               }
               
               Spacer()
               
               // Action buttons
               VStack(spacing: CloveSpacing.small) {
                  Button("Edit") {
                     withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        onEdit()
                     }
                  }
                  .font(CloveFonts.small())
                  .foregroundStyle(Theme.shared.accent)
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
                  colors: [Theme.shared.accent.opacity(0.05), Theme.shared.accent.opacity(0.02)],
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
                        [Theme.shared.accent.opacity(0.3), Theme.shared.accent.opacity(0.2)] :
                           [Theme.shared.accent.opacity(0.1), Theme.shared.accent.opacity(0.05)],
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

struct ModernSymptomEmptyStateView: View {
   var body: some View {
      VStack(spacing: CloveSpacing.large) {
         Image(systemName: "bandage")
            .font(.system(size: 48))
            .foregroundStyle(
               LinearGradient(
                  colors: [Theme.shared.accent.opacity(0.6), Theme.shared.accent.opacity(0.3)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
               )
            )
         
         VStack(spacing: CloveSpacing.small) {
            Text("No symptoms added yet")
               .font(.system(.title3, design: .rounded).weight(.semibold))
               .foregroundStyle(CloveColors.primaryText)
            
            Text("Add your first symptom above to get started")
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
                  .stroke(Theme.shared.accent.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 2)
      )
   }
}

struct SymptomInputField: View {
   let icon: String
   let title: String
   let placeholder: String
   @Binding var text: String
   let isRequired: Bool
   var isTextFieldFocused: FocusState<Bool>.Binding
   let onSubmit: (() -> Void)?
   
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
         
         TextField(placeholder, text: $text)
            .padding(CloveSpacing.medium)
            .background(
               RoundedRectangle(cornerRadius: CloveCorners.medium)
                  .fill(CloveColors.card)
                  .overlay(
                     RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(Theme.shared.accent.opacity(0.2), lineWidth: 1)
                  )
                  .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
            )
            .focused(isTextFieldFocused)
            .onSubmit {
               onSubmit?()
            }
      }
   }
}

struct SymptomEditField: View {
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
                     .stroke(Theme.shared.accent.opacity(0.2), lineWidth: 1)
               )
         )
   }
}

struct SymptomAddButton: View {
   let title: String
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
            
            Text(isLoading ? "Adding..." : title)
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
                     colors: isEnabled ? [Theme.shared.accent, Theme.shared.accent.opacity(0.8)] : [CloveColors.secondaryText, CloveColors.secondaryText.opacity(0.8)],
                     startPoint: .topLeading,
                     endPoint: .bottomTrailing
                  )
               )
               .shadow(
                  color: isEnabled ? Theme.shared.accent.opacity(0.3) : .clear,
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

#Preview {
   EditSymptomsSheet(
      trackedSymptoms: [
         TrackedSymptom(id: 1, name: "Headache"),
         TrackedSymptom(id: 2, name: "Fatigue"),
         TrackedSymptom(id: 3, name: "Joint Pain")
      ]
   )
}
