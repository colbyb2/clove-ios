import SwiftUI

// MARK: - Section Header
struct SectionHeaderView: View {
    let title: String
    let icon: String?
    let emoji: String?
    
    init(title: String, icon: String? = nil, emoji: String? = nil) {
        self.title = title
        self.icon = icon
        self.emoji = emoji
    }
    
    var body: some View {
        HStack(spacing: CloveSpacing.small) {
            if let emoji = emoji {
                Text(emoji)
                    .font(.system(size: 18))
            } else if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.shared.accent)
            }
            
            Text(title)
                .font(CloveFonts.sectionTitle())
                .foregroundStyle(CloveColors.primaryText)
            
            Spacer()
        }
    }
}

// MARK: - Rating Display
struct RatingDisplayView: View {
    let value: Int
    let maxValue: Int
    let label: String
    let emoji: String?
    let color: Color
    
    init(value: Int, maxValue: Int = 10, label: String, emoji: String? = nil, color: Color = Theme.shared.accent) {
        self.value = value
        self.maxValue = maxValue
        self.label = label
        self.emoji = emoji
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: CloveSpacing.medium) {
            // Label with emoji
            HStack(spacing: CloveSpacing.small) {
                if let emoji = emoji {
                    Text(emoji)
                        .font(.system(size: 16))
                }
                Text(label)
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.primaryText)
            }
            
            Spacer()
            
            // Rating value
            Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            
            Text("/ \(maxValue)")
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)
        }
        .padding(.horizontal, CloveSpacing.medium)
        .padding(.vertical, CloveSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Progress Bar Rating
struct ProgressRatingView: View {
    let value: Int
    let maxValue: Int
    let label: String
    let color: Color
    
    private var progress: Double {
        Double(value) / Double(maxValue)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            HStack {
                Text(label)
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
                
                Text("\(value)/\(maxValue)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(CloveColors.background)
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * progress, height: 8)
                        .cornerRadius(4)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, CloveSpacing.medium)
        .padding(.vertical, CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Tag List Display
struct TagListView: View {
    let items: [String]
    let color: Color
    
    init(items: [String], color: Color = Theme.shared.accent) {
        self.items = items
        self.color = color
    }
    
    var body: some View {
        if !items.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: CloveSpacing.small) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(CloveFonts.small())
                        .padding(.horizontal, CloveSpacing.small)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(color.opacity(0.1))
                        )
                        .foregroundStyle(color)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, CloveSpacing.medium)
            .padding(.vertical, CloveSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(CloveColors.card)
                    .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
            )
        }
    }
}

// MARK: - Notes Display
struct NotesDisplayView: View {
    let notes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            Text(notes)
                .font(CloveFonts.body())
                .foregroundStyle(CloveColors.primaryText)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: CloveSpacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(CloveColors.secondaryText.opacity(0.6))
            
            VStack(spacing: CloveSpacing.small) {
                Text(title)
                    .font(CloveFonts.sectionTitle())
                    .foregroundStyle(CloveColors.primaryText)
                
                Text(subtitle)
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(CloveSpacing.xlarge)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Data Card Container
struct DataCardView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            content
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 2)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        SectionHeaderView(title: "Physical Health", emoji: "🩹")
        
        RatingDisplayView(value: 7, label: "Pain Level", emoji: "🩹", color: .orange)
        
        ProgressRatingView(value: 8, maxValue: 10, label: "Energy Level", color: CloveColors.green)
        
        TagListView(items: ["Breakfast", "Lunch", "Snack"], color: Theme.shared.accent)
        
        NotesDisplayView(notes: "Had a good day overall. Felt energetic in the morning but pain increased in the afternoon.")
        
        EmptyStateView(
            icon: "note.text",
            title: "No Notes",
            subtitle: "No additional notes were recorded for this day"
        )
    }
    .padding()
    .background(CloveColors.background)
}
