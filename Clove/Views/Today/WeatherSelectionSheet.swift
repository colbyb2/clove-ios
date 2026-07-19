import SwiftUI

struct WeatherSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedWeather: String?
    
    private let weatherOptions: [(name: String, symbol: String)] = [
        ("Sunny", "sun.max.fill"),
        ("Cloudy", "cloud.fill"),
        ("Rainy", "cloud.rain.fill"),
        ("Stormy", "cloud.bolt.rain.fill"),
        ("Snow", "cloud.snow.fill"),
        ("Gloomy", "cloud.fog.fill")
    ]
    
    @State private var animateIn = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("What's the weather like?")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(CloveColors.primary)
                
                Text("Select today's weather conditions")
                    .font(.system(.subheadline))
                    .foregroundStyle(CloveColors.secondaryText)
            }
            .multilineTextAlignment(.center)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : -20)
            
            // Weather Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(weatherOptions, id: \.name) { weather in
                    WeatherOptionCard(
                        name: weather.name,
                        symbol: weather.symbol,
                        isSelected: selectedWeather == weather.name
                    ) {
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        selectedWeather = weather.name
                        
                        // Dismiss after brief delay to show selection
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            dismiss()
                        }
                    }
                }
            }
            .padding(.horizontal)
            .opacity(animateIn ? 1 : 0)
            .scaleEffect(animateIn ? 1 : 0.8)
            
            Spacer()
        }
        .padding(.top, 30)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                animateIn = true
            }
        }
    }
}

struct WeatherOptionCard: View {
    let name: String
    let symbol: String
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : Theme.shared.accent)
                    .scaleEffect(isSelected ? 1.2 : 1.0)
                
                Text(name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(isSelected ? .white : CloveColors.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(isSelected ? Theme.shared.accent : CloveColors.card)
                    .shadow(
                        color: isSelected ? Theme.shared.accent.opacity(0.3) : .gray.opacity(0.2),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityLabel("\(name) weather")
        .accessibilityHint(isSelected ? "Currently selected" : "Tap to select \(name.lowercased()) weather")
    }
}

#Preview {
    WeatherSelectionSheet(selectedWeather: .constant(nil))
}
