import SwiftUI

struct TagInputView: View {
    let title: String
    let placeholder: String
    let type: SuggestionType
    let color: Color
    @Binding var items: [String]
    
    @State private var inputText = ""
    @State private var showingSuggestions = false
    @State private var suggestions: [String] = []
    @FocusState private var isTextFieldFocused: Bool
    
    private let suggestionRepo = SuggestionRepository.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            // Header
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Spacer()
            }
            .onTapGesture {
                isTextFieldFocused = false
            }
            
            // Current items display
            if !items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(items, id: \.self) { item in
                            TagChip(text: item, color: color) {
                                removeItem(item)
                            }
                        }
                    }
                    .padding(.horizontal, 2) // Small padding for shadow
                }
                .padding(.bottom, CloveSpacing.small)
                .onTapGesture {
                    isTextFieldFocused = false
                }
            }
            
            // Input field
            VStack(spacing: 0) {
                HStack {
                    TextField(placeholder, text: $inputText)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            addCurrentInput()
                        }
                        .onChange(of: inputText) { _, newValue in
                            updateSuggestions(for: newValue)
                        }
                    
                    if !inputText.isEmpty {
                        Button("Add") {
                            addCurrentInput()
                        }
                        .foregroundStyle(color)
                        .fontWeight(.semibold)
                        .frame(minWidth: 44, minHeight: 44)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(CloveColors.card)
                .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
                .onTapGesture {
                    isTextFieldFocused = true
                }
                
                // Suggestions dropdown
                if showingSuggestions && !suggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(action: {
                                addItem(suggestion)
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
        .onAppear {
            updateSuggestions(for: "")
        }
        .onChange(of: isTextFieldFocused) { _, focused in
            withAnimation(.easeInOut(duration: 0.2)) {
                showingSuggestions = focused
            }
        }
    }
    
    private func updateSuggestions(for query: String) {
        suggestions = suggestionRepo.getFilteredSuggestions(for: type, query: query)
            .filter { !items.contains($0) } // Don't suggest already added items
    }
    
    private func addCurrentInput() {
        addItem(inputText)
    }
    
    private func addItem(_ item: String) {
        let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty && !items.contains(trimmed) else { return }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            items.append(trimmed)
        }
        
        // Save to suggestions
        suggestionRepo.addSuggestion(trimmed, for: type)
        
        // Clear input and update suggestions
        inputText = ""
        updateSuggestions(for: "")
    }
    
    private func removeItem(_ item: String) {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            items.removeAll { $0 == item }
        }
        
        updateSuggestions(for: inputText)
    }
}

struct TagChip: View {
    let text: String
    let color: Color
    let onRemove: () -> Void
    
    private var displayText: String {
        if text.count <= 10 {
            return text
        } else {
            return String(text.prefix(8)) + "..."
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Text(displayText)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(width: 16, height: 16)
            .accessibilityLabel("Remove \(text)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: color.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    TagInputView(
        title: "Meals",
        placeholder: "Add a meal...",
        type: .meals,
        color: .green,
        items: .constant(["Pizza", "Salad"])
    )
    .padding()
}