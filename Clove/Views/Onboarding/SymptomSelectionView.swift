import SwiftUI

struct SymptomSelectionView: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var customName = ""
    @State private var duplicateName = false
    @State private var appeared = false
    @FocusState private var nameFieldFocused: Bool

    private let suggestions = [
        "Headache", "Fatigue", "Nausea", "Joint Pain",
        "Brain Fog", "Dizziness", "Sleep Issues", "Stomach Pain"
    ]

    private let columns = [GridItem(.adaptive(minimum: 112), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Choose your symptoms")
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(CloveColors.primaryText)
                        Spacer()
                        if !viewModel.trackedSymptoms.isEmpty {
                            Text("\(viewModel.trackedSymptoms.count) added")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.shared.accent)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Theme.shared.accent.opacity(0.11), in: Capsule())
                        }
                    }
                    Text("Add the main symptoms you want close at hand. You can add as many as you need and fine-tune them later.")
                        .font(.subheadline)
                        .foregroundStyle(CloveColors.secondaryText)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Common symptoms")
                        .font(.headline)
                        .foregroundStyle(CloveColors.primaryText)

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                        ForEach(suggestions, id: \.self) { symptom in
                            suggestionButton(symptom)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("Add your own")
                        .font(.headline)
                        .foregroundStyle(CloveColors.primaryText)

                    HStack(spacing: 9) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Theme.shared.accent)

                        TextField("Type a symptom name", text: $customName)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .focused($nameFieldFocused)
                            .onSubmit(addCustomSymptom)

                        Button(action: addCustomSymptom) {
                            Text("Add")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(Theme.shared.accent, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                    }
                    .padding(12)
                    .background(CloveColors.card, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(duplicateName ? CloveColors.error : Theme.shared.accent.opacity(nameFieldFocused ? 0.45 : 0.1), lineWidth: 1.5))

                    if duplicateName {
                        Text("That symptom is already in your list.")
                            .font(.caption)
                            .foregroundStyle(CloveColors.error)
                    }
                }

                if !viewModel.trackedSymptoms.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your symptoms")
                                .font(.headline)
                                .foregroundStyle(CloveColors.primaryText)
                            Text("Choose whether each symptom uses a 0–10 rating or a simple Yes/No.")
                                .font(.caption)
                                .foregroundStyle(CloveColors.secondaryText)
                        }

                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.trackedSymptoms.enumerated()), id: \.element.name) { index, symptom in
                                symptomRow(symptom, index: index)
                                if index < viewModel.trackedSymptoms.count - 1 {
                                    Divider().padding(.leading, 44)
                                }
                            }
                        }
                        .background(CloveColors.card, in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(CloveColors.secondaryText.opacity(0.08)))
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Label("You can continue without adding symptoms and set them up later.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(CloveColors.secondaryText)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(CloveColors.card, in: RoundedRectangle(cornerRadius: 13))
                }
            }
            .padding(.horizontal, CloveSpacing.medium)
            .padding(.top, 8)
            .padding(.bottom, 92)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 18)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            Button {
                nameFieldFocused = false
                viewModel.nextStep()
            } label: {
                Text(viewModel.trackedSymptoms.isEmpty ? "Continue without symptoms" : "Continue")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Theme.shared.accent, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, CloveSpacing.medium)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.58, dampingFraction: 0.86)) {
                    appeared = true
                }
            }
        }
    }

    private func suggestionButton(_ name: String) -> some View {
        let selected = viewModel.trackedSymptoms.contains {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                viewModel.toggleSuggestedSymptom(name)
            }
            duplicateName = false
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: selected ? "checkmark.circle.fill" : "plus.circle")
                Text(name).lineLimit(1)
            }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(selected ? Theme.shared.accent : CloveColors.primaryText)
            .frame(maxWidth: .infinity, minHeight: 40)
            .padding(.horizontal, 9)
            .background(selected ? Theme.shared.accent.opacity(0.11) : CloveColors.card, in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(selected ? Theme.shared.accent.opacity(0.3) : CloveColors.secondaryText.opacity(0.09)))
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? "Added" : "Not added")
    }

    private func symptomRow(_ symptom: TrackedSymptom, index: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "bandage.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.shared.accent)
                .frame(width: 32, height: 32)
                .background(Theme.shared.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 9))

            Text(symptom.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CloveColors.primaryText)
                .lineLimit(1)

            Spacer(minLength: 6)

            Menu {
                Button("0–10 rating") { viewModel.setSymptomScale(at: index, isBinary: false) }
                Button("Yes / No") { viewModel.setSymptomScale(at: index, isBinary: true) }
            } label: {
                HStack(spacing: 4) {
                    Text(symptom.isBinary ? "Yes / No" : "0–10")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.shared.accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(Theme.shared.accent.opacity(0.1), in: Capsule())
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.removeSymptom(at: index)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(CloveColors.secondaryText)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(symptom.name)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func addCustomSymptom() {
        let added = viewModel.addSymptom(name: customName)
        duplicateName = !added && !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard added else { return }
        customName = ""
        duplicateName = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

#Preview {
    SymptomSelectionView()
        .environment(OnboardingViewModel())
}
