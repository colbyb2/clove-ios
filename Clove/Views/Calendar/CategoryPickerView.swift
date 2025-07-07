import SwiftUI

struct CategoryPickerView: View {
    let categories: [TrackingCategory]
    @Binding var selectedCategory: TrackingCategory
    @State private var viewMode: ViewMode = .allData
    
    enum ViewMode: String, CaseIterable {
        case allData = "All Data"
        case category = "By Category"
    }
    
    var body: some View {
        VStack(spacing: CloveSpacing.medium) {
            // Main segmented control
            Picker("View Mode", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewMode) { _, newMode in
                if newMode == .allData {
                    selectedCategory = .allData
                } else if selectedCategory == .allData {
                    // Switch to first available category when switching from "All Data"
                    selectedCategory = categories.first { $0 != .allData } ?? .mood
                }
            }
            
            // Horizontal scrollable category picker (only show when in category mode)
            if viewMode == .category {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CloveSpacing.medium) {
                        ForEach(categories.filter { $0 != .allData }) { category in
                            CategoryChip(
                                category: category,
                                isSelected: selectedCategory == category,
                                onTap: {
                                    selectedCategory = category
                                }
                            )
                        }
                    }
                    .padding(.horizontal, CloveSpacing.medium)
                }
            }
        }
        .padding(.vertical, CloveSpacing.small)
        .onAppear {
            // Set initial view mode based on selected category
            viewMode = selectedCategory == .allData ? .allData : .category
        }
    }
}

struct CategoryChip: View {
    let category: TrackingCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: CloveSpacing.small) {
                Text(category.emoji)
                    .font(.system(size: 16))
                
                Text(category.displayName)
                    .font(CloveFonts.body())
                    .fontWeight(isSelected ? .semibold : .medium)
                    .lineLimit(1)
            }
            .padding(.horizontal, CloveSpacing.medium)
            .padding(.vertical, CloveSpacing.small)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.full)
                    .fill(isSelected ? Theme.shared.accent : CloveColors.card)
                    .shadow(
                        color: isSelected ? Theme.shared.accent.opacity(0.3) : .black.opacity(0.05),
                        radius: isSelected ? 4 : 2,
                        x: 0,
                        y: isSelected ? 2 : 1
                    )
            )
            .foregroundStyle(isSelected ? .white : CloveColors.primaryText)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        CategoryPickerView(
            categories: [
                .allData,
                .mood,
                .pain,
                .energy,
                .symptom(id: 1, name: "Headache"),
                .symptom(id: 2, name: "Fatigue")
            ],
            selectedCategory: .constant(.mood)
        )
        
        Spacer()
    }
    .padding()
}
