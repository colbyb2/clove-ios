import SwiftUI

struct AdvancedDiscoveryView: View {
    enum Section: String, CaseIterable, Identifiable {
        case discoveries = "Findings"
        case context = "Context"
        case baselines = "Baselines"
        case hypotheses = "Hypotheses"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .discoveries: return "sparkles"
            case .context: return "calendar.badge.clock"
            case .baselines: return "scope"
            case .hypotheses: return "lightbulb"
            }
        }
    }

    let viewModel: InsightsHomeViewModel
    @State private var section: Section = .discoveries
    @State private var showingNewHypothesis = false

    var body: some View {
        VStack(spacing: 0) {
            sectionPicker
            ScrollView {
                Group {
                    switch section {
                    case .discoveries: discoveries
                    case .context: context
                    case .baselines: baselines
                    case .hypotheses: hypotheses
                    }
                }
                .padding(CloveSpacing.large)
                .padding(.bottom, 80)
            }
        }
        .background(CloveColors.background.ignoresSafeArea())
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingNewHypothesis) {
            NewHypothesisSheet(viewModel: viewModel)
        }
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Section.allCases) { item in
                    Button {
                        section = item
                    } label: {
                        Label(item.rawValue, systemImage: item.icon)
                            .font(.subheadline.bold())
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .foregroundStyle(section == item ? Color.white : CloveColors.primaryText)
                            .background(section == item ? Theme.shared.accent : CloveColors.card, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, CloveSpacing.large)
            .padding(.vertical, 10)
        }
        .background(CloveColors.background)
    }

    @ViewBuilder private var discoveries: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            sectionHeading("Automatic findings", caption: discoveryCaption)
            if viewModel.visibleDiscoveries.isEmpty {
                compactEmpty("No reliable findings yet", icon: "sparkles",
                             detail: "This range did not contain a relationship that passed the data, effect-size, and false-discovery checks.")
            } else {
                ForEach(viewModel.visibleDiscoveries) { discovery in
                    discoveryCard(discovery)
                }
            }

            sectionHeading("Recorded patterns", caption: "Patterns found directly in your tracked history")
                .padding(.top, 6)
            if viewModel.insights.isEmpty {
                compactEmpty("No repeated patterns yet", icon: "calendar",
                             detail: "Consistent tracking gives the app more recorded days to compare.")
            } else {
                ForEach(viewModel.insights) { insight in patternCard(insight) }
            }
        }
    }

    private var discoveryCaption: String {
        guard let run = viewModel.discoveryRun else { return "Looking for useful patterns in what you recorded" }
        return "Clove checked \(run.testedPairCount) possible connections and only shows patterns that passed its reliability checks."
    }

    private func discoveryCard(_ discovery: AutomaticDiscovery) -> some View {
        let feedback = viewModel.feedback(for: discovery.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(discovery.title)
                        .font(.caption.bold())
                        .foregroundStyle(Theme.shared.accent)
                    Text(discoverySummary(discovery))
                        .font(.headline)
                }
                Spacer()
                if feedback.isSaved { Image(systemName: "bookmark.fill").foregroundStyle(Theme.shared.accent) }
            }

            HStack(spacing: 8) {
                plainBadge("\(discovery.estimate.strength) pattern", icon: "waveform.path", color: Theme.shared.accent)
                plainBadge(coverageLabel(discovery.matchedCoverage), icon: "checkmark.circle", color: coverageColor(discovery.matchedCoverage))
            }

            Text("This pattern appeared across \(discovery.estimate.sampleCount) days when you recorded both items.")
                .font(.subheadline)
                .foregroundStyle(CloveColors.secondaryText)

            DisclosureGroup("Why Clove is showing this") {
                VStack(alignment: .leading, spacing: 7) {
                    Text("The two items moved together consistently enough to pass Clove’s safeguards against showing random coincidences.")
                    Text("This is a clue worth watching—not proof that one item caused the other.")
                    ForEach(discovery.limitations, id: \.self) { Text("• \($0)") }

                    Divider().padding(.vertical, 2)
                    Text("Technical details").fontWeight(.semibold)
                    Text("Method: \(discovery.estimate.method.displayName)")
                    if let effect = discovery.estimate.effect {
                        Text("Relationship score: \(effect.formatted(.number.precision(.fractionLength(2))))")
                    }
                    Text("Adjusted reliability value: \(adjustedValue(discovery.qValue))")
                }
                .font(.caption)
                .foregroundStyle(CloveColors.secondaryText)
                .padding(.top, 8)
            }
            .font(.subheadline.bold())
            feedbackControls(id: discovery.id)
        }
        .cardStyle()
    }

    private func patternCard(_ insight: HealthInsight) -> some View {
        let feedbackID = "pattern|\(insight.id)"
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top) {
                Image(systemName: insight.typeIcon).foregroundStyle(Theme.shared.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(insight.title).font(.headline)
                    Text(insight.description).font(.subheadline).foregroundStyle(CloveColors.secondaryText)
                }
                Spacer(minLength: 0)
            }
            if let evidence = insight.evidence {
                Text("Seen across \(evidence.sampleCount) recorded observations")
                    .font(.caption).foregroundStyle(CloveColors.secondaryText)
            }
            feedbackControls(id: feedbackID, allowsDismissal: false)
        }
        .cardStyle()
    }

    private func feedbackControls(id: String, allowsDismissal: Bool = true) -> some View {
        let feedback = viewModel.feedback(for: id)
        return HStack(spacing: 5) {
            actionButton("Useful", icon: feedback.feedbackRating == .useful ? "hand.thumbsup.fill" : "hand.thumbsup") {
                viewModel.setRating(.useful, for: id)
            }
            actionButton("Not for me", icon: feedback.feedbackRating == .notUseful ? "hand.thumbsdown.fill" : "hand.thumbsdown") {
                viewModel.setRating(.notUseful, for: id)
            }
            Spacer(minLength: 2)
            Button { viewModel.toggleSaved(id) } label: {
                Image(systemName: feedback.isSaved ? "bookmark.fill" : "bookmark")
            }
            .accessibilityLabel(feedback.isSaved ? "Remove saved finding" : "Save finding")
            if allowsDismissal {
                Menu {
                    Button("Hide for 30 days") { viewModel.dismiss(id) }
                } label: { Image(systemName: "ellipsis") }
                .accessibilityLabel("Finding options")
            }
        }
        .font(.caption.bold())
        .foregroundStyle(Theme.shared.accent)
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon).labelStyle(.iconOnly) }
            .accessibilityLabel(title)
            .frame(minWidth: 32, minHeight: 32)
    }

    @ViewBuilder private var context: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            sectionHeading("Patterns during your cycle", caption: "How your tracked metrics compared with your usual levels during each cycle phase")
            if let result = viewModel.contextAnalysis, !result.phaseSummaries.isEmpty {
                ForEach(result.phaseSummaries.prefix(12)) { summary in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(summary.metricName).font(.headline)
                        Text(cycleSummary(summary))
                            .font(.subheadline)
                        Text("Seen in \(summary.observationCount) recordings across \(summary.cycleCount) cycles")
                            .font(.caption).foregroundStyle(CloveColors.secondaryText)
                    }
                    .cardStyle()
                }
            } else {
                compactEmpty("Not enough repeated cycle data", icon: "calendar.badge.clock",
                    detail: "Mark at least three cycle starts and record the same metric during two complete cycles.")
            }

            sectionHeading("What was different on flare days", caption: "Flare days compared with your other logged days")
                .padding(.top, 6)
            if let result = viewModel.contextAnalysis, !result.flareComparisons.isEmpty {
                ForEach(result.flareComparisons.prefix(12)) { comparison in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(comparison.metricName).font(.headline)
                        Text(flareSummary(comparison))
                            .font(.subheadline)
                        Text("Compared \(comparison.flareDayCount) flare days with \(comparison.nonFlareDayCount) other days")
                            .font(.caption).foregroundStyle(CloveColors.secondaryText)
                    }
                    .cardStyle()
                }
            } else {
                compactEmpty("Not enough flare comparisons", icon: "waveform.path.ecg",
                    detail: "At least three explicitly marked flare days and three other logged days are required.")
            }
            Text("Context comparisons describe your recorded history. They do not diagnose a condition or establish a cause.")
                .font(.caption).foregroundStyle(CloveColors.secondaryText)
        }
    }

    @ViewBuilder private var baselines: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            sectionHeading("Compared with your usual", caption: "Your latest seven recordings compared with your own recent history")
            if viewModel.baselines.isEmpty {
                compactEmpty("No qualified baselines yet", icon: "scope",
                    detail: "A baseline needs 28 historical and 7 recent observations within the last 120 days.")
            } else {
                ForEach(viewModel.baselines) { baseline in
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text(baseline.metricName).font(.headline)
                            Spacer()
                            Text(baselineStatus(baseline)).font(.caption.bold())
                                .foregroundStyle(baseline.position == .typical ? Color.green : Theme.shared.accent)
                                .padding(.horizontal, 9).padding(.vertical, 5)
                                .background((baseline.position == .typical ? Color.green : Theme.shared.accent).opacity(0.12), in: Capsule())
                        }
                        Text(baselineSummary(baseline)).font(.subheadline)
                        Text("Recent: \(plainNumber(baseline.recentValue)) · Your usual: \(plainNumber(baseline.center))")
                            .font(.caption).foregroundStyle(CloveColors.secondaryText)
                        Text("Your usual range is based on \(baseline.baselineObservationCount) earlier recordings")
                            .font(.caption).foregroundStyle(CloveColors.secondaryText)
                        if baseline.isQualifiedByGap {
                            Label("Includes a tracking gap longer than 30 days", systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }.cardStyle()
                }
            }
            Text("Higher or lower only means different from your own usual pattern. It does not automatically mean better or worse.")
                .font(.caption).foregroundStyle(CloveColors.secondaryText)
        }
    }

    @ViewBuilder private var hypotheses: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                sectionHeading("Things to watch", caption: "Personal questions you want to revisit")
                Spacer()
                Button { showingNewHypothesis = true } label: { Label("New", systemImage: "plus") }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).tint(Theme.shared.accent)
            }
            if viewModel.hypotheses.isEmpty {
                compactEmpty("No saved hypotheses", icon: "lightbulb",
                    detail: "Create a question about two metrics, keep tracking, then review what the data shows.")
            } else {
                ForEach(viewModel.hypotheses) { hypothesis in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(hypothesis.title).font(.headline)
                        Text("\(metricName(hypothesis.factorMetricID)) ↔ \(metricName(hypothesis.outcomeMetricID))")
                            .font(.subheadline).foregroundStyle(Theme.shared.accent)
                        if !hypothesis.notes.isEmpty { Text(hypothesis.notes).font(.subheadline).foregroundStyle(CloveColors.secondaryText) }
                        Text(reviewText(hypothesis)).font(.caption).foregroundStyle(CloveColors.secondaryText)
                        HStack {
                            Button("Reviewed today") { viewModel.markReviewed(hypothesis) }.buttonStyle(.bordered)
                            Spacer()
                            Button(role: .destructive) { viewModel.deleteHypothesis(hypothesis) } label: {
                                Image(systemName: "trash")
                            }.accessibilityLabel("Delete hypothesis")
                        }
                    }.cardStyle()
                }
            }
            Text("A saved hypothesis is a tracking plan, not evidence or proof. Results remain exploratory until the recorded data supports them.")
                .font(.caption).foregroundStyle(CloveColors.secondaryText)
        }
    }

    private func reviewText(_ hypothesis: SavedHypothesis) -> String {
        guard let last = hypothesis.lastReviewedAt else { return "Review every \(hypothesis.reviewIntervalDays) days · not reviewed yet" }
        return "Review every \(hypothesis.reviewIntervalDays) days · last reviewed \(last.formatted(date: .abbreviated, time: .omitted))"
    }

    private func metricName(_ id: String) -> String {
        viewModel.dataset?.definitions.first { $0.id.rawValue == id }?.displayName ?? id
    }

    private func discoverySummary(_ discovery: AutomaticDiscovery) -> String {
        guard let effect = discovery.estimate.effect else {
            return "These two items showed a possible connection."
        }
        guard discovery.estimate.method.signed else {
            return "These two items tended to vary together in your records."
        }

        let movesUp = effect > 0
        if discovery.factor.measurementLevel == .binary {
            let direction = movesUp ? "higher or more common" : "lower or less common"
            return "On days when \(discovery.factor.displayName) was recorded, \(discovery.outcome.displayName) tended to be \(direction)."
        }
        if discovery.outcome.measurementLevel == .binary {
            let frequency = movesUp ? "more" : "less"
            return "When \(discovery.factor.displayName) was higher, \(discovery.outcome.displayName) was \(frequency) often recorded."
        }
        let direction = movesUp ? "higher" : "lower"
        return "When \(discovery.factor.displayName) was higher, \(discovery.outcome.displayName) tended to be \(direction)."
    }

    private func plainBadge(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func coverageLabel(_ coverage: Double) -> String {
        if coverage >= 0.8 { return "Good data match" }
        if coverage >= 0.6 { return "Fair data match" }
        return "Limited data match"
    }

    private func coverageColor(_ coverage: Double) -> Color {
        coverage >= 0.8 ? .green : coverage >= 0.6 ? Theme.shared.accent : .orange
    }

    private func adjustedValue(_ value: Double) -> String {
        value < 0.001 ? "<0.001" : value.formatted(.number.precision(.fractionLength(3)))
    }

    private func cycleSummary(_ summary: CyclePhaseSummary) -> String {
        let difference = summary.differenceFromPersonalMean
        if abs(difference) < 0.05 {
            return "During the \(summary.phase.rawValue.lowercased()) phase, this was close to your usual level."
        }
        let direction = difference > 0 ? "higher" : "lower"
        return "During the \(summary.phase.rawValue.lowercased()) phase, this was typically \(plainNumber(abs(difference))) \(direction) than your overall average."
    }

    private func flareSummary(_ comparison: FlareComparison) -> String {
        if abs(comparison.difference) < 0.05 {
            return "This was about the same on flare days and other logged days."
        }
        let direction = comparison.difference > 0 ? "higher" : "lower"
        return "On flare days, this was typically \(plainNumber(abs(comparison.difference))) \(direction) than on your other logged days."
    }

    private func baselineStatus(_ baseline: PersonalBaseline) -> String {
        switch baseline.position {
        case .typical: "Within usual range"
        case .above: "Higher than usual"
        case .below: "Lower than usual"
        }
    }

    private func baselineSummary(_ baseline: PersonalBaseline) -> String {
        switch baseline.position {
        case .typical:
            "Your latest recordings are close to your usual pattern."
        case .above:
            "Your latest recordings are \(plainNumber(abs(baseline.difference))) higher than your usual level."
        case .below:
            "Your latest recordings are \(plainNumber(abs(baseline.difference))) lower than your usual level."
        }
    }

    private func plainNumber(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    private func sectionHeading(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title3.bold())
            Text(caption).font(.caption).foregroundStyle(CloveColors.secondaryText)
        }
    }

    private func compactEmpty(_ title: String, icon: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(Theme.shared.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.bold())
                Text(detail).font(.caption).foregroundStyle(CloveColors.secondaryText)
            }
        }.cardStyle()
    }
}

private struct NewHypothesisSheet: View {
    let viewModel: InsightsHomeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var factorID = ""
    @State private var outcomeID = ""
    @State private var notes = ""
    @State private var reviewDays = 7

    private var definitions: [MetricDefinition] {
        viewModel.dataset?.definitions.filter { $0.supportedAnalyses.contains(.relationship) }.sorted { $0.displayName < $1.displayName } ?? []
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Question") {
                    TextField("What do you want to watch?", text: $title)
                    Picker("First metric", selection: $factorID) {
                        ForEach(definitions) { Text($0.displayName).tag($0.id.rawValue) }
                    }
                    Picker("Second metric", selection: $outcomeID) {
                        ForEach(definitions) { Text($0.displayName).tag($0.id.rawValue) }
                    }
                    TextField("Notes (optional)", text: $notes, axis: .vertical).lineLimit(2...5)
                }
                Section("Check-in") {
                    Stepper("Review every \(reviewDays) days", value: $reviewDays, in: 3...30)
                }
                Section {
                    Text("This saves a tracking question. It does not create a finding or prove a relationship.")
                        .font(.caption).foregroundStyle(CloveColors.secondaryText)
                }
            }
            .navigationTitle("New Hypothesis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.addHypothesis(title: title, factorID: factorID, outcomeID: outcomeID,
                                                notes: notes, reviewDays: reviewDays)
                        dismiss()
                    }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || factorID == outcomeID)
                }
            }
            .onAppear {
                if factorID.isEmpty { factorID = definitions.first?.id.rawValue ?? "" }
                if outcomeID.isEmpty { outcomeID = definitions.dropFirst().first?.id.rawValue ?? "" }
            }
        }
    }
}

private extension View {
    func cardStyle() -> some View {
        padding(CloveSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
    }
}
