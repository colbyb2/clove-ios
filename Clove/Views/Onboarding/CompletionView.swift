import SwiftUI

struct OnboardingTermsView: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showFullTerms = false
    @State private var appeared = false

    private var terms: Popup {
        Popups.all.first { $0.id == "termsAndConditions" }!
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(Theme.shared.accent)
                        .frame(width: 54, height: 54)
                        .background(Theme.shared.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

                    Text("One last thing")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(CloveColors.primaryText)

                    Text("Please review and accept Clove’s terms before starting your first check-in.")
                        .font(.subheadline)
                        .foregroundStyle(CloveColors.secondaryText)
                        .lineSpacing(3)
                }

                VStack(spacing: 0) {
                    legalSummaryRow(
                        icon: "cross.case.fill",
                        title: "Clove is not medical advice",
                        detail: "Use it as a personal tracking tool and consult qualified professionals for medical decisions."
                    )
                    Divider().padding(.leading, 54)
                    legalSummaryRow(
                        icon: "iphone.gen3",
                        title: "You control your records",
                        detail: "Records stay locally on this device unless you choose to export or share them."
                    )
                    Divider().padding(.leading, 54)
                    legalSummaryRow(
                        icon: "chart.xyaxis.line",
                        title: "Patterns are informational",
                        detail: "Correlations can be incomplete or misleading and should not guide treatment decisions."
                    )
                }
                .background(CloveColors.card, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(CloveColors.secondaryText.opacity(0.09)))

                DisclosureGroup(isExpanded: $showFullTerms) {
                    Text(terms.message)
                        .font(.caption)
                        .foregroundStyle(CloveColors.secondaryText)
                        .lineSpacing(3)
                        .padding(.top, 12)
                        .textSelection(.enabled)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.plaintext")
                            .foregroundStyle(Theme.shared.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Read the full terms")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(CloveColors.primaryText)
                            Text("Last updated September 18, 2026")
                                .font(.caption)
                                .foregroundStyle(CloveColors.secondaryText)
                        }
                    }
                }
                .tint(Theme.shared.accent)
                .padding(14)
                .background(CloveColors.card, in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(CloveColors.secondaryText.opacity(0.09)))

                Text("By continuing, you confirm that you have read and agree to the Terms and Conditions.")
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)

                Button {
                    PopupManager.shared.markAccepted(terms)
                    viewModel.nextStep()
                } label: {
                    Text("Agree & Continue")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.shared.accent, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, CloveSpacing.large)
            .padding(.top, 10)
            .padding(.bottom, 28)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 18)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.62, dampingFraction: 0.86)) {
                    appeared = true
                }
            }
        }
    }

    private func legalSummaryRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.shared.accent)
                .frame(width: 34, height: 34)
                .background(Theme.shared.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CloveColors.primaryText)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
    }
}

struct CompleteView: View {
    @Environment(AppState.self) private var appState
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var isLaunching = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [Theme.shared.accent.opacity(0.14), CloveColors.background, CloveColors.background],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer(minLength: 28)

                        successMark

                        VStack(spacing: 9) {
                            Text("Your check-in is ready")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundStyle(CloveColors.primaryText)
                                .multilineTextAlignment(.center)
                            Text("Start with today. Clove will make your history and patterns more useful as you continue.")
                                .font(.subheadline)
                                .foregroundStyle(CloveColors.secondaryText)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }

                        setupSummary

                        if let error = viewModel.completionError {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(CloveColors.error)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(CloveColors.error.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
                        }

                        VStack(spacing: 11) {
                            Button {
                                finish(showTutorial: false)
                            } label: {
                                HStack(spacing: 8) {
                                    if isLaunching {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                    Text(isLaunching ? "Finishing setup…" : "Start today’s check-in")
                                }
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(Theme.shared.accent, in: RoundedRectangle(cornerRadius: 15))
                                .shadow(color: Theme.shared.accent.opacity(0.25), radius: 10, y: 5)
                            }
                            .buttonStyle(.plain)
                            .disabled(isLaunching)

                            Button("Show me around first") {
                                finish(showTutorial: true)
                            }
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.shared.accent)
                            .frame(minHeight: 42)
                            .disabled(isLaunching)
                        }

                        Label("No account required · Your health data stays on this device", systemImage: "lock.shield.fill")
                            .font(.caption)
                            .foregroundStyle(CloveColors.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, max(geometry.safeAreaInsets.bottom, 16))
                    }
                    .padding(.horizontal, CloveSpacing.large)
                    .frame(minHeight: geometry.size.height)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 22)
                    .scaleEffect(isLaunching && !reduceMotion ? 1.015 : 1)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.72, dampingFraction: 0.82)) {
                    appeared = true
                }
            }
        }
    }

    private var successMark: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Theme.shared.accent.opacity(0.13 - Double(index) * 0.025), lineWidth: 2)
                    .frame(width: 108 + CGFloat(index * 18), height: 108 + CGFloat(index * 18))
                    .scaleEffect(appeared ? 1 : 0.7)
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Theme.shared.accent, Theme.shared.accent.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 96, height: 96)
                .shadow(color: Theme.shared.accent.opacity(0.28), radius: 16, y: 8)

            Image(systemName: "checkmark")
                .font(.system(size: 39, weight: .bold))
                .foregroundStyle(.white)
                .scaleEffect(appeared ? 1 : 0.4)
        }
    }

    private var setupSummary: some View {
        VStack(spacing: 0) {
            summaryRow(
                icon: "checklist",
                title: "Daily check-in",
                detail: "\(enabledFeatureCount) features selected"
            )

            Divider().padding(.leading, 52)

            summaryRow(
                icon: "bandage.fill",
                title: "Symptoms",
                detail: viewModel.baseSettings.trackSymptoms
                    ? (viewModel.trackedSymptoms.isEmpty ? "Ready to add later" : "\(viewModel.trackedSymptoms.count) added")
                    : "Not included"
            )

            Divider().padding(.leading, 52)

            summaryRow(
                icon: "paintpalette.fill",
                title: "Theme",
                detail: "Personalized for you"
            )
        }
        .background(CloveColors.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(CloveColors.secondaryText.opacity(0.09)))
    }

    private func summaryRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.shared.accent)
                .frame(width: 34, height: 34)
                .background(Theme.shared.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CloveColors.primaryText)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(CloveColors.success)
        }
        .padding(13)
    }

    private var enabledFeatureCount: Int {
        let settings = viewModel.baseSettings
        let values = [
            settings.trackMood, settings.trackPain, settings.trackEnergy, settings.trackHydration,
            settings.trackSymptoms, settings.trackMeals, settings.trackActivities, settings.trackMeds,
            settings.showFlareToggle, settings.trackWeather, settings.trackNotes,
            settings.trackBowelMovements, settings.trackCycle, viewModel.pacingPlansEnabled
        ]
        return values.filter { $0 }.count
    }

    private func finish(showTutorial: Bool) {
        guard !isLaunching else { return }
        isLaunching = true
        viewModel.completionError = nil

        Task { @MainActor in
            if !reduceMotion {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                    isLaunching = true
                }
                try? await Task.sleep(for: .milliseconds(320))
            }

            let succeeded = viewModel.completeOnboarding(appState: appState, showTutorial: showTutorial)
            if !succeeded {
                isLaunching = false
            }
        }
    }
}

#Preview {
    CompleteView()
        .environment(OnboardingViewModel())
        .environment(AppState())
}
