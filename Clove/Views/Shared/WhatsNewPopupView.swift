import SwiftUI

struct WhatsNewPopupView: View {
    let popup: Popup

    @State private var isVisible = false
    @State private var selectedFeature = 0

    private var features: [WhatsNewFeature] {
        popup.features ?? []
    }

    private var isLastFeature: Bool {
        features.isEmpty || selectedFeature == features.count - 1
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.62)
                    .ignoresSafeArea()
                    .opacity(isVisible ? 1 : 0)

                popupContent
                    .frame(maxWidth: 430)
                    .frame(height: min(geometry.size.height - 48, 620))
                    .padding(.horizontal, 20)
                    .scaleEffect(isVisible ? 1 : 0.94)
                    .opacity(isVisible ? 1 : 0)
            }
        }
        .animation(.easeOut(duration: 0.25), value: isVisible)
        .onAppear {
            isVisible = true
        }
    }

    private var popupContent: some View {
        VStack(spacing: 0) {
            header

            if features.isEmpty {
                emptyFeatureContent
            } else {
                featurePager
                pageIndicator
            }

            actions
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.3), radius: 28, y: 14)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.shared.accent.opacity(0.14))

                    Image(systemName: popup.icon ?? "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.shared.accent)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text("WHAT'S NEW")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(Theme.shared.accent)

                    Text(popup.title)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(CloveColors.primaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Button(action: dismissPopup) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(CloveColors.secondaryText)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(CloveColors.background))
                }
                .accessibilityLabel("Close what's new")
            }

            HStack {
                if let version = popup.version {
                    Text("Version \(version)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CloveColors.secondaryText)
                }

                Spacer()

                if !features.isEmpty {
                    Text("\(selectedFeature + 1) of \(features.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CloveColors.secondaryText)
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }

    private var featurePager: some View {
        TabView(selection: $selectedFeature) {
            ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                featurePage(feature)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxHeight: .infinity)
    }

    private func featurePage(_ feature: WhatsNewFeature) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 4)

            ZStack {
                Circle()
                    .fill(Theme.shared.accent.opacity(0.12))
                    .frame(width: 112, height: 112)

                Circle()
                    .stroke(Theme.shared.accent.opacity(0.18), lineWidth: 1)
                    .frame(width: 112, height: 112)

                Image(systemName: feature.icon)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Theme.shared.accent)
            }

            VStack(spacing: 10) {
                Text(feature.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(CloveColors.primaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(feature.description)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(CloveColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 26)

            Spacer(minLength: 4)
        }
        .accessibilityElement(children: .combine)
    }

    private var emptyFeatureContent: some View {
        Text(popup.message)
            .font(.system(size: 17))
            .foregroundStyle(CloveColors.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 28)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(features.indices, id: \.self) { index in
                Capsule()
                    .fill(index == selectedFeature ? Theme.shared.accent : CloveColors.secondaryText.opacity(0.25))
                    .frame(width: index == selectedFeature ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: selectedFeature)
            }
        }
        .padding(.bottom, 18)
        .accessibilityHidden(true)
    }

    private var actions: some View {
        HStack(spacing: 12) {
            if selectedFeature > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedFeature -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.shared.accent)
                        .frame(width: 52, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Theme.shared.accent.opacity(0.12))
                        )
                }
                .accessibilityLabel("Previous feature")
                .transition(.scale.combined(with: .opacity))
            }

            Button(action: advanceOrDismiss) {
                HStack(spacing: 8) {
                    Text(isLastFeature ? "Start exploring" : "Next")
                    Image(systemName: isLastFeature ? "checkmark" : "arrow.right")
                }
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.shared.accent)
                )
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 22)
        .background(CloveColors.card)
        .overlay(alignment: .top) {
            Divider().opacity(0.35)
        }
        .animation(.easeInOut(duration: 0.2), value: selectedFeature)
    }

    private func advanceOrDismiss() {
        if isLastFeature {
            dismissPopup()
        } else {
            let feedback = UISelectionFeedbackGenerator()
            feedback.selectionChanged()

            withAnimation(.easeInOut(duration: 0.25)) {
                selectedFeature += 1
            }
        }
    }

    private func dismissPopup() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.easeIn(duration: 0.2)) {
            isVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            PopupManager.shared.close()
        }
    }
}

#Preview {
    ZStack {
        CloveColors.background.ignoresSafeArea()

        WhatsNewPopupView(popup: WhatsNewContent.version_1_6_0)
    }
}
