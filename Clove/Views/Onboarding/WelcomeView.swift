import SwiftUI

struct CloveIntroView: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var logoAppeared = false
    @State private var wordmarkAppeared = false
    @State private var actionAppeared = false
    @State private var orbitRotation = 0.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [Theme.shared.accent.opacity(0.2), CloveColors.background, CloveColors.background],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(Theme.shared.accent.opacity(0.08))
                    .frame(width: 360, height: 360)
                    .blur(radius: 55)
                    .offset(y: -110)

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 28) {
                        animatedMark

                        VStack(spacing: 9) {
                            Text("Clove")
                                .font(.system(size: 50, weight: .bold, design: .rounded))
                                .foregroundStyle(CloveColors.primaryText)
                                .tracking(-1.5)

                            Text("Track gently. Understand clearly.")
                                .font(.system(.title3, design: .rounded, weight: .medium))
                                .foregroundStyle(CloveColors.secondaryText)
                        }
                        .opacity(wordmarkAppeared ? 1 : 0)
                        .offset(y: wordmarkAppeared ? 0 : 16)
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        Button {
                            viewModel.nextStep()
                        } label: {
                            HStack(spacing: 8) {
                                Text("Begin")
                                Image(systemName: "arrow.right")
                            }
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                LinearGradient(
                                    colors: [Theme.shared.accent, Theme.shared.accent.opacity(0.75)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .shadow(color: Theme.shared.accent.opacity(0.28), radius: 12, y: 6)
                        }
                        .buttonStyle(.plain)

                        Text("Private by design · No account required")
                            .font(.caption)
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 24))
                    .opacity(actionAppeared ? 1 : 0)
                    .offset(y: actionAppeared ? 0 : 24)
                }
            }
        }
        .onAppear(perform: runIntro)
    }

    private var animatedMark: some View {
        ZStack {
            Circle()
                .stroke(Theme.shared.accent.opacity(0.13), lineWidth: 1.5)
                .frame(width: 174, height: 174)

            Circle()
                .trim(from: 0.04, to: 0.42)
                .stroke(
                    LinearGradient(
                        colors: [Theme.shared.accent.opacity(0.1), Theme.shared.accent.opacity(0.75)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 174, height: 174)
                .rotationEffect(.degrees(orbitRotation))

            Circle()
                .fill(Theme.shared.accent.opacity(0.14))
                .frame(width: 142, height: 142)
                .blur(radius: 7)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Theme.shared.accent, Theme.shared.accent.opacity(0.66)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 116, height: 116)
                .shadow(color: Theme.shared.accent.opacity(0.32), radius: 22, y: 9)

            Image(systemName: "leaf.fill")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(logoAppeared ? -7 : -42))

            Circle()
                .fill(.white)
                .frame(width: 9, height: 9)
                .shadow(color: Theme.shared.accent.opacity(0.5), radius: 5)
                .offset(y: -87)
                .rotationEffect(.degrees(orbitRotation))
        }
        .scaleEffect(logoAppeared ? 1 : 0.58)
        .opacity(logoAppeared ? 1 : 0)
    }

    private func runIntro() {
        if reduceMotion {
            logoAppeared = true
            wordmarkAppeared = true
            actionAppeared = true
            return
        }

        withAnimation(.spring(response: 0.8, dampingFraction: 0.68)) {
            logoAppeared = true
        }
        withAnimation(.spring(response: 0.62, dampingFraction: 0.84).delay(0.28)) {
            wordmarkAppeared = true
        }
        withAnimation(.spring(response: 0.58, dampingFraction: 0.86).delay(0.52)) {
            actionAppeared = true
        }
        withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
            orbitRotation = 360
        }
    }
}

struct WelcomeView: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [Theme.shared.accent.opacity(0.14), CloveColors.background, CloveColors.background],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 28)

                    VStack(spacing: 22) {
                        heroMark

                        VStack(spacing: 10) {
                            Text("Your health, in context")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundStyle(CloveColors.primaryText)
                                .multilineTextAlignment(.center)

                            Text("A private health tracker shaped around what matters to you.")
                                .font(.system(.title3, design: .rounded))
                                .foregroundStyle(CloveColors.secondaryText)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                    }
                    .padding(.horizontal, 28)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 18)

                    Spacer(minLength: 26)

                    VStack(spacing: 10) {
                        valueRow(icon: "checkmark.circle.fill", title: "Quick daily check-ins", detail: "Track only what is useful to you")
                        valueRow(icon: "calendar.badge.clock", title: "A history you can revisit", detail: "See what changed and when")
                        valueRow(icon: "sparkles", title: "Patterns made clearer", detail: "Turn consistent tracking into useful context")
                    }
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 24)

                    Spacer(minLength: 24)

                    VStack(spacing: 12) {
                        Button {
                            viewModel.nextStep()
                        } label: {
                            HStack(spacing: 8) {
                                Text("Set up my tracker")
                                Image(systemName: "arrow.right")
                            }
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                LinearGradient(
                                    colors: [Theme.shared.accent, Theme.shared.accent.opacity(0.78)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .shadow(color: Theme.shared.accent.opacity(0.25), radius: 12, y: 6)
                        }
                        .buttonStyle(.plain)

                        Label("No account required · Data stays on this device", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 22))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 30)
                }
            }
        }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.75, dampingFraction: 0.82)) {
                    appeared = true
                }
            }
        }
    }

    private var heroMark: some View {
        ZStack {
            Circle()
                .fill(Theme.shared.accent.opacity(0.12))
                .frame(width: 142, height: 142)
                .blur(radius: 8)
                .scaleEffect(appeared ? 1 : 0.72)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Theme.shared.accent, Theme.shared.accent.opacity(0.68)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 108, height: 108)
                .shadow(color: Theme.shared.accent.opacity(0.28), radius: 18, y: 8)

            Image(systemName: "leaf.fill")
                .font(.system(size: 45, weight: .medium))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(appeared ? 0 : -18))
        }
    }

    private func valueRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.shared.accent)
                .frame(width: 38, height: 38)
                .background(Theme.shared.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(CloveColors.primaryText)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)
            }
            Spacer()
        }
        .padding(12)
        .background(CloveColors.card.opacity(0.86), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CloveColors.secondaryText.opacity(0.08)))
    }
}

#Preview {
    WelcomeView()
        .environment(OnboardingViewModel())
}
