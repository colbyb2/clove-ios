import SwiftUI

struct ColorSchemeSelectionView: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appColor = Theme.shared.accent
    @State private var selectedThemeID: String?
    @State private var appeared = false

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private let themes = [
        OnboardingTheme(name: "Ocean", description: "Clear and calm", color: Color(hex: "4A90E2"), icon: "water.waves"),
        OnboardingTheme(name: "Sage", description: "Soft and natural", color: Color(hex: "66AF56"), icon: "leaf.fill"),
        OnboardingTheme(name: "Sunset", description: "Warm and bright", color: Color(hex: "F77A54"), icon: "sun.max.fill"),
        OnboardingTheme(name: "Low color", description: "Quiet grayscale", color: Color(hex: "7C7C7C"), icon: "circle.lefthalf.filled")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(appColor.opacity(0.13))
                        .frame(width: 112, height: 112)
                        .blur(radius: 7)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [appColor, appColor.opacity(0.68)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 82, height: 82)
                        .shadow(color: appColor.opacity(0.26), radius: 14, y: 7)
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.white)
                }
                .scaleEffect(appeared ? 1 : 0.7)

                VStack(spacing: 8) {
                    Text("Make Clove feel like yours")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(CloveColors.primaryText)
                        .multilineTextAlignment(.center)
                    Text("Choose a color that feels comfortable and easy to recognize. Low color keeps the interface quieter.")
                        .font(.subheadline)
                        .foregroundStyle(CloveColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(themes) { theme in
                        themeCard(theme)
                    }
                }

                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(appColor)
                        .frame(width: 38, height: 38)
                        .background(appColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choose a custom color")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(CloveColors.primaryText)
                        Text("Pick any accent that works for you")
                            .font(.caption)
                            .foregroundStyle(CloveColors.secondaryText)
                    }

                    Spacer()

                    ColorPicker("Custom color", selection: $appColor, supportsOpacity: false)
                        .labelsHidden()
                }
                .padding(13)
                .background(CloveColors.card, in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(appColor.opacity(0.22)))

                VStack(spacing: 11) {
                    Button(action: useTheme) {
                        Text("Use this theme")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(
                                LinearGradient(colors: [appColor, appColor.opacity(0.76)], startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .shadow(color: appColor.opacity(0.24), radius: 9, y: 4)
                    }
                    .buttonStyle(.plain)

                    Button("Keep current theme") {
                        viewModel.selectedColorString = Theme.shared.accent.toString()
                        viewModel.nextStep()
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(CloveColors.secondaryText)
                    .frame(minHeight: 40)
                }
            }
            .padding(.horizontal, CloveSpacing.large)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
        }
        .scrollIndicators(.hidden)
        .onChange(of: appColor) { _, newColor in
            if let selectedThemeID,
               let selected = themes.first(where: { $0.id == selectedThemeID }),
               selected.color.toString() != newColor.toString() {
                self.selectedThemeID = nil
            }
        }
        .onAppear {
            if let saved = viewModel.selectedColorString.toColor() {
                appColor = saved
            }

            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.68, dampingFraction: 0.84)) {
                    appeared = true
                }
            }
        }
    }

    private func themeCard(_ theme: OnboardingTheme) -> some View {
        let selected = selectedThemeID == theme.id
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedThemeID = theme.id
                appColor = theme.color
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: theme.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.color)
                        .frame(width: 35, height: 35)
                        .background(theme.color.opacity(0.13), in: Circle())
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? theme.color : CloveColors.secondaryText.opacity(0.4))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    Text(theme.description)
                        .font(.caption)
                        .foregroundStyle(CloveColors.secondaryText)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .background(selected ? theme.color.opacity(0.07) : CloveColors.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? theme.color.opacity(0.3) : CloveColors.secondaryText.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    private func useTheme() {
        Theme.shared.accent = appColor
        viewModel.selectedColorString = appColor.toString()
        viewModel.nextStep()
    }
}

private struct OnboardingTheme: Identifiable {
    let name: String
    let description: String
    let color: Color
    let icon: String
    var id: String { name }
}

#Preview {
    ColorSchemeSelectionView()
        .environment(OnboardingViewModel())
}
