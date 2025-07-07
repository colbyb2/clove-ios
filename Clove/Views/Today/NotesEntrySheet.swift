import SwiftUI

struct NotesEntrySheet: View {
    @Binding var notes: String?
    let date: Date
    
    @Environment(\.dismiss) private var dismiss
    @State private var noteText: String = ""
    @State private var hasUnsavedChanges: Bool = false
    @FocusState private var isTextEditorFocused: Bool
    
    private let characterLimit = 2000
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Content area
                VStack(alignment: .leading, spacing: CloveSpacing.large) {
                    // Date header
                    VStack(alignment: .leading, spacing: CloveSpacing.small) {
                        Text("Notes for")
                            .font(CloveFonts.small())
                            .foregroundStyle(CloveColors.secondaryText)
                        
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(.title2, design: .rounded).weight(.semibold))
                            .foregroundStyle(CloveColors.primaryText)
                    }
                    .padding(.horizontal, CloveSpacing.large)
                    .padding(.top, CloveSpacing.medium)
                    
                    // Text editor area
                    VStack(alignment: .leading, spacing: CloveSpacing.small) {
                        HStack {
                            Text("Write your thoughts...")
                                .font(CloveFonts.body())
                                .foregroundStyle(CloveColors.secondaryText)
                            
                            Spacer()
                            
                            // Character count
                            Text("\(noteText.count)/\(characterLimit)")
                                .font(CloveFonts.small())
                                .foregroundStyle(noteText.count > characterLimit ? CloveColors.error : CloveColors.secondaryText)
                        }
                        .padding(.horizontal, CloveSpacing.large)
                        
                        // Text editor with custom styling
                        ZStack(alignment: .topLeading) {
                            if noteText.isEmpty {
                                Text("How are you feeling today? Any observations about your symptoms, activities, or general wellbeing...")
                                    .font(CloveFonts.body())
                                    .foregroundStyle(CloveColors.secondaryText.opacity(0.6))
                                    .padding(.horizontal, CloveSpacing.medium)
                                    .padding(.vertical, CloveSpacing.small + 2)
                                    .allowsHitTesting(false)
                            }
                            
                            TextEditor(text: $noteText)
                                .font(CloveFonts.body())
                                .foregroundStyle(CloveColors.primaryText)
                                .focused($isTextEditorFocused)
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, CloveSpacing.small)
                                .onChange(of: noteText) { oldValue, newValue in
                                    // Track changes for unsaved indicator
                                    hasUnsavedChanges = newValue != (notes ?? "")
                                    
                                    // Enforce character limit
                                    if newValue.count > characterLimit {
                                        noteText = String(newValue.prefix(characterLimit))
                                        // Haptic feedback when hitting limit
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                        impactFeedback.impactOccurred()
                                    }
                                }
                        }
                        .frame(minHeight: 200)
                        .background(
                            RoundedRectangle(cornerRadius: CloveCorners.medium)
                                .fill(CloveColors.card)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                                        .stroke(
                                            isTextEditorFocused ? Theme.shared.accent.opacity(0.5) : CloveColors.secondaryText.opacity(0.2),
                                            lineWidth: isTextEditorFocused ? 2 : 1
                                        )
                                )
                                .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
                        )
                        .padding(.horizontal, CloveSpacing.large)
                        .animation(.easeInOut(duration: 0.2), value: isTextEditorFocused)
                        
                        // Helper text
                        if noteText.count > characterLimit - 100 {
                            Text("Approaching character limit")
                                .font(CloveFonts.small())
                                .foregroundStyle(CloveColors.orange)
                                .padding(.horizontal, CloveSpacing.large)
                        }
                    }
                    
                    Spacer()
                }
                
                // Bottom action area
                VStack(spacing: CloveSpacing.medium) {
                    // Save button
                    Button(action: saveNotes) {
                        HStack(spacing: CloveSpacing.small) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Text("Save Notes")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: CloveCorners.medium)
                                .fill(Theme.shared.accent)
                                .shadow(color: Theme.shared.accent.opacity(0.3), radius: 4, x: 0, y: 2)
                        )
                    }
                    .disabled(noteText.count > characterLimit)
                    .opacity(noteText.count > characterLimit ? 0.6 : 1.0)
                    .accessibilityLabel("Save notes")
                    .accessibilityHint("Saves your notes for this day")
                    
                    // Clear button (only show if there's content)
                    if !noteText.isEmpty {
                        Button(action: clearNotes) {
                            HStack(spacing: CloveSpacing.small) {
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .medium))
                                
                                Text("Clear Notes")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundStyle(CloveColors.error)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: CloveCorners.medium)
                                    .fill(CloveColors.error.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                                            .stroke(CloveColors.error.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .accessibilityLabel("Clear notes")
                        .accessibilityHint("Removes all text from notes")
                    }
                }
                .padding(.horizontal, CloveSpacing.large)
                .padding(.bottom, CloveSpacing.large)
            }
            .background(CloveColors.background.ignoresSafeArea())
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            // Show confirmation for unsaved changes
                            showUnsavedChangesAlert()
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundStyle(CloveColors.secondaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if hasUnsavedChanges {
                        Circle()
                            .fill(Theme.shared.accent)
                            .frame(width: 8, height: 8)
                            .accessibilityLabel("Unsaved changes")
                    }
                }
            }
        }
        .onAppear {
            // Pre-populate with existing notes
            noteText = notes ?? ""
            // Auto-focus the text editor
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextEditorFocused = true
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Actions
    
    private func saveNotes() {
        let trimmedText = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        notes = trimmedText.isEmpty ? nil : trimmedText
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        dismiss()
    }
    
    private func clearNotes() {
        noteText = ""
        hasUnsavedChanges = true
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func showUnsavedChangesAlert() {
        // For now, just dismiss - could add alert in future
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    NotesEntrySheet(
        notes: .constant("Sample notes text that might be longer to test the preview..."),
        date: Date()
    )
}

#Preview("Empty Notes") {
    NotesEntrySheet(
        notes: .constant(nil),
        date: Date()
    )
}