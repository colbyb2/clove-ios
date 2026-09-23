import SwiftUI

struct PacingPlanTracker: View {
    let date: Date
    var onPlansChanged: (() -> Void)? = nil

    @State private var items: [PacingPlanItem] = []
    @State private var showAddPlan = false

    private let repo = PacingPlanRepo.shared

    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            HStack(spacing: CloveSpacing.small) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Theme.shared.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gentle Plans")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(CloveColors.primaryText)
                    Text("Ideas for the day, not obligations")
                        .font(.caption)
                        .foregroundStyle(CloveColors.secondaryText)
                }
                Spacer()
                Button {
                    showAddPlan = true
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.shared.accent)
                        .frame(minHeight: 44)
                }
                .accessibilityHint("Adds an optional plan for this day")
            }

            if items.isEmpty {
                HStack(spacing: CloveSpacing.small) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Theme.shared.accent)
                    Text("Nothing planned")
                        .font(.subheadline)
                        .foregroundStyle(CloveColors.secondaryText)
                }
                .padding(.vertical, CloveSpacing.small)
            } else {
                VStack(spacing: CloveSpacing.small) {
                    ForEach(items) { item in
                        planRow(item)
                    }
                }
            }

            Text("Plans stay separate from logged activities and never affect your insights.")
                .font(.caption2)
                .foregroundStyle(CloveColors.secondaryText)
        }
        .padding(.vertical, CloveSpacing.small)
        .onAppear(perform: loadItems)
        .onChange(of: date) { _, _ in loadItems() }
        .sheet(isPresented: $showAddPlan) {
            AddPacingPlanSheet(date: date) {
                loadItems()
            }
            .presentationDetents([.height(390)])
            .presentationDragIndicator(.visible)
        }
    }

    private func planRow(_ item: PacingPlanItem) -> some View {
        HStack(spacing: 12) {
            Button {
                setState(item.state == .completed ? .planned : .completed, for: item)
            } label: {
                Image(systemName: item.state == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.state == .completed ? CloveColors.success : Theme.shared.accent)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.state == .completed ? "Mark \(item.title) as planned" : "Mark \(item.title) as done")

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(item.state == .completed ? CloveColors.secondaryText : CloveColors.primaryText)
                    .strikethrough(item.state == .completed)
                if item.state == .deferred {
                    Label("Saved for later", systemImage: "pause.circle.fill")
                        .font(.caption)
                        .foregroundStyle(CloveColors.secondaryText)
                }
            }

            Spacer()

            Menu {
                if item.state != .planned {
                    Button { setState(.planned, for: item) } label: {
                        Label("Keep on list", systemImage: "circle")
                    }
                }
                if item.state != .completed {
                    Button { setState(.completed, for: item) } label: {
                        Label("Mark done", systemImage: "checkmark.circle")
                    }
                }
                if item.state != .deferred {
                    Button { setState(.deferred, for: item) } label: {
                        Label("Save for later", systemImage: "pause.circle")
                    }
                }
                Divider()
                Button(role: .destructive) { remove(item) } label: {
                    Label("Remove", systemImage: "xmark.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(CloveColors.secondaryText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Options for \(item.title)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(CloveColors.card.opacity(0.65), in: RoundedRectangle(cornerRadius: CloveCorners.small))
    }

    private func setState(_ state: PacingPlanState, for item: PacingPlanItem) {
        guard repo.setState(state, for: item) else {
            showFailure()
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) { loadItems() }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func remove(_ item: PacingPlanItem) {
        guard repo.setState(.removed, for: item) else {
            showFailure()
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) { loadItems() }
        ToastManager.shared.showToast(
            message: "Plan removed",
            color: CloveColors.secondaryText,
            icon: Image(systemName: "leaf"),
            duration: 8,
            actionTitle: "Undo"
        ) {
            if repo.setState(item.state, for: item) { loadItems() }
        }
    }

    private func loadItems() {
        items = repo.visibleItems(for: date)
        onPlansChanged?()
    }

    private func showFailure() {
        ToastManager.shared.showToast(
            message: "That plan couldn't be updated. Please try again.",
            color: CloveColors.error,
            icon: Image(systemName: "exclamationmark.triangle")
        )
    }
}

private struct AddPacingPlanSheet: View {
    let date: Date
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.shared.accent)
                        .frame(width: 42, height: 42)
                        .background(Theme.shared.accent.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Make space for something gentle")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(CloveColors.primaryText)
                        Text("Optional, flexible, and just for you")
                            .font(.subheadline)
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("YOUR PLAN")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isFocused ? Theme.shared.accent : CloveColors.secondaryText)
                        .tracking(0.8)

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.shared.accent)
                            .padding(.top, 2)

                        TextField("A short walk, call a friend…", text: $title, axis: .vertical)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(CloveColors.primaryText)
                            .lineLimit(2...3)
                            .focused($isFocused)
                            .submitLabel(.done)
                            .onSubmit(save)

                        if !title.isEmpty {
                            Button {
                                title = ""
                                isFocused = true
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(CloveColors.secondaryText.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear plan")
                        }
                    }
                    .padding(14)
                    .frame(minHeight: 64, alignment: .top)
                    .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
                    .overlay {
                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                            .stroke(
                                isFocused ? Theme.shared.accent.opacity(0.75) : CloveColors.secondaryText.opacity(0.12),
                                lineWidth: isFocused ? 1.5 : 1
                            )
                    }
                    .shadow(color: .black.opacity(isFocused ? 0.07 : 0.03), radius: 7, x: 0, y: 3)

                    HStack {
                        Label(
                            date.formatted(date: .abbreviated, time: .omitted),
                            systemImage: "calendar"
                        )
                        Spacer()
                        Text("\(cleanTitle.count)/120")
                    }
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)
                }

                Button(action: save) {
                    Label("Add to Plans", systemImage: "plus")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            cleanTitle.isEmpty ? CloveColors.secondaryText.opacity(0.35) : Theme.shared.accent,
                            in: RoundedRectangle(cornerRadius: CloveCorners.medium)
                        )
                }
                .buttonStyle(.plain)
                .disabled(cleanTitle.isEmpty)

                Label("Plans stay separate from activity tracking and insights.", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(CloveSpacing.large)
            .background(CloveColors.background)
            .navigationTitle("New Gentle Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { isFocused = true }
        }
    }

    private var cleanTitle: String {
        String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
    }

    private func save() {
        guard !cleanTitle.isEmpty else { return }
        if PacingPlanRepo.shared.add(title: cleanTitle, for: date) {
            onSaved()
            dismiss()
        } else {
            ToastManager.shared.showToast(
                message: "That plan couldn't be added. Please try again.",
                color: CloveColors.error,
                icon: Image(systemName: "exclamationmark.triangle")
            )
        }
    }
}

#Preview {
    PacingPlanTracker(date: Date())
        .padding()
        .background(CloveColors.background)
}
