import SwiftUI

struct AdvancedDiscoveryView: View {
    enum ExploreSection: String, CaseIterable, Identifiable {
        case connections = "Connections"
        case changes = "Changes & trends"
        case flares = "Flare days"
        case cycles = "Cycle patterns"
        case baselines = "Compared with usual"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .connections: return "point.3.connected.trianglepath.dotted"
            case .changes: return "chart.line.uptrend.xyaxis"
            case .flares: return "waveform.path.ecg"
            case .cycles: return "calendar.badge.clock"
            case .baselines: return "scope"
            }
        }
        var tint: Color {
            switch self {
            case .connections: return .cyan
            case .changes: return .purple
            case .flares: return .orange
            case .cycles: return .pink
            case .baselines: return .green
            }
        }
    }

    let viewModel: InsightsHomeViewModel
    @State private var showingNewHypothesis = false
    @State private var exploreSearchText = ""

    private enum SpotlightItem: Identifiable {
        case discovery(AutomaticDiscovery)
        case pattern(HealthInsight)

        var id: String {
            switch self {
            case .discovery(let value): return "discovery|\(value.id)"
            case .pattern(let value): return "pattern|\(value.id)"
            }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                worthALook
                explore
                watchingPreview
            }
            .padding(CloveSpacing.large)
            .padding(.bottom, 80)
        }
        .background(CloveColors.background.ignoresSafeArea())
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingNewHypothesis) {
            NewHypothesisSheet(viewModel: viewModel)
        }
    }

    @ViewBuilder private var worthALook: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Worth a look", caption: "The clearest, most relevant signals in this range")
            if spotlightItems.isEmpty {
                compactEmpty("Nothing strong enough to highlight yet", icon: "sparkles",
                             detail: "Keep tracking and Clove will surface reliable changes and connections here.")
            } else {
                ForEach(spotlightItems) { item in
                    NavigationLink {
                        spotlightDetail(item)
                    } label: {
                        spotlightCard(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var explore: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Explore your data", caption: "Choose a question instead of sorting through one long feed")
            VStack(spacing: 0) {
                ForEach(Array(ExploreSection.allCases.enumerated()), id: \.element.id) { index, item in
                    NavigationLink {
                        explorePage(item)
                    } label: {
                        HStack(spacing: 13) {
                            Image(systemName: item.icon)
                                .font(.headline)
                                .foregroundStyle(item.tint)
                                .frame(width: 38, height: 38)
                                .background(item.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 11))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.rawValue).font(.subheadline.bold())
                                Text(exploreCaption(item)).font(.caption).foregroundStyle(CloveColors.secondaryText)
                            }
                            Spacer()
                            Text(exploreCount(item).formatted())
                                .font(.caption.bold()).foregroundStyle(CloveColors.secondaryText)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(CloveColors.background, in: Capsule())
                            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(CloveColors.secondaryText)
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    if index < ExploreSection.allCases.count - 1 { Divider().padding(.leading, 51) }
                }
            }
            .padding(.horizontal, CloveSpacing.medium)
            .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
        }
    }

    private var watchingPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Watching", caption: "Saved findings and questions you want to revisit")
            NavigationLink {
                watching
            } label: {
                HStack(spacing: 13) {
                    Image(systemName: "bookmark.fill").foregroundStyle(.yellow)
                        .frame(width: 38, height: 38).background(Color.yellow.opacity(0.13), in: RoundedRectangle(cornerRadius: 11))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(watchingCount == 0 ? "Start watching what matters" : "\(watchingCount) saved to revisit")
                            .font(.subheadline.bold())
                        Text("Keep findings and personal tracking questions together")
                            .font(.caption).foregroundStyle(CloveColors.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(CloveColors.secondaryText)
                }
                .cardStyle()
            }
            .buttonStyle(.plain)
        }
    }

    private var spotlightItems: [SpotlightItem] {
        var results: [SpotlightItem] = []
        var usedMetrics = Set<String>()

        for discovery in rankedDiscoveries where viewModel.feedback(for: discovery.id).feedbackRating != .notUseful {
            let metrics = [discovery.factor.id.rawValue, discovery.outcome.id.rawValue]
            guard usedMetrics.isDisjoint(with: metrics) else { continue }
            results.append(.discovery(discovery))
            usedMetrics.formUnion(metrics)
            if results.count == 3 { return results }
        }

        for insight in curatedPatterns {
            guard usedMetrics.isDisjoint(with: insight.associatedMetrics) else { continue }
            results.append(.pattern(insight))
            usedMetrics.formUnion(insight.associatedMetrics)
            if results.count == 3 { break }
        }
        return results
    }

    private var curatedPatterns: [HealthInsight] {
        var seen = Set<String>()
        return viewModel.insights
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority.rawValue > rhs.priority.rawValue }
                return lhs.confidence > rhs.confidence
            }
            .filter { insight in
                let key = insight.associatedMetrics.sorted().joined(separator: "|")
                return seen.insert(key).inserted
            }
    }

    private var rankedDiscoveries: [AutomaticDiscovery] {
        viewModel.visibleDiscoveries.sorted { lhs, rhs in
            let lhsFeedback = viewModel.feedback(for: lhs.id).feedbackRating
            let rhsFeedback = viewModel.feedback(for: rhs.id).feedbackRating
            let lhsBoost = lhsFeedback == .useful ? 1 : lhsFeedback == .notUseful ? -1 : 0
            let rhsBoost = rhsFeedback == .useful ? 1 : rhsFeedback == .notUseful ? -1 : 0
            if lhsBoost != rhsBoost { return lhsBoost > rhsBoost }
            return lhs.rankScore > rhs.rankScore
        }
    }

    private var atypicalBaselines: [PersonalBaseline] { viewModel.baselines.filter { $0.position != .typical } }
    private var typicalBaselines: [PersonalBaseline] { viewModel.baselines.filter { $0.position == .typical } }
    private var savedDiscoveries: [AutomaticDiscovery] { viewModel.visibleDiscoveries.filter { viewModel.feedback(for: $0.id).isSaved } }
    private var savedPatterns: [HealthInsight] { viewModel.insights.filter { viewModel.feedback(for: "pattern|\($0.id)").isSaved } }
    private var watchingCount: Int { savedDiscoveries.count + savedPatterns.count + viewModel.hypotheses.count }

    private func exploreCount(_ section: ExploreSection) -> Int {
        switch section {
        case .connections: return viewModel.visibleDiscoveries.count
        case .changes: return curatedPatterns.count
        case .flares: return viewModel.contextAnalysis?.flareComparisons.count ?? 0
        case .cycles: return viewModel.contextAnalysis?.phaseSummaries.count ?? 0
        case .baselines: return atypicalBaselines.count
        }
    }

    private func exploreCaption(_ section: ExploreSection) -> String {
        switch section {
        case .connections: return "Metrics that moved together"
        case .changes: return "Shifts, trends, and repeated patterns"
        case .flares: return "What differed on marked flare days"
        case .cycles: return "Patterns across recorded cycle phases"
        case .baselines: return "What recently changed from your usual"
        }
    }

    private func spotlightCard(_ item: SpotlightItem) -> some View {
        let presentation: (icon: String, color: Color, eyebrow: String, title: String, detail: String)
        switch item {
        case .discovery(let discovery):
            presentation = ("point.3.connected.trianglepath.dotted", .cyan, "CONNECTION",
                            discoverySummary(discovery),
                            "Based on \(discovery.estimate.sampleCount) matched days")
        case .pattern(let insight):
            presentation = (insight.typeIcon, .purple, "CHANGE",
                            insight.title,
                            insight.evidence?.compactSummary ?? insight.description)
        }
        return HStack(alignment: .top, spacing: 13) {
            Image(systemName: presentation.icon)
                .font(.headline).foregroundStyle(presentation.color)
                .frame(width: 40, height: 40)
                .background(presentation.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                Text(presentation.eyebrow).font(.caption2.bold()).foregroundStyle(presentation.color)
                Text(presentation.title).font(.headline).foregroundStyle(CloveColors.primaryText)
                Text(presentation.detail).font(.caption).foregroundStyle(CloveColors.secondaryText)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(CloveColors.secondaryText)
                .padding(.top, 12)
        }
        .cardStyle()
    }

    @ViewBuilder private func spotlightDetail(_ item: SpotlightItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch item {
                case .discovery(let discovery): discoveryCard(discovery)
                case .pattern(let insight): patternCard(insight)
                }
                Text("Clove describes patterns in what you recorded. A pattern is not proof that one item caused another and is not a diagnosis.")
                    .font(.caption).foregroundStyle(CloveColors.secondaryText)
            }
            .padding(CloveSpacing.large).padding(.bottom, 60)
        }
        .background(CloveColors.background.ignoresSafeArea())
        .navigationTitle("Finding")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func explorePage(_ section: ExploreSection) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                sectionHeading(section.rawValue, caption: exploreCaption(section))
                exploreSearchField
                switch section {
                case .connections:
                    let discoveries = rankedDiscoveries.filter {
                        matchesSearch($0.title, discoverySummary($0), $0.factor.displayName, $0.outcome.displayName)
                    }
                    if discoveries.isEmpty {
                        compactEmpty("No reliable connections yet", icon: section.icon,
                                     detail: exploreSearchText.isEmpty
                                        ? "No pair in this range passed Clove’s data and reliability checks."
                                        : "Try a different metric or phrase.")
                    } else {
                        ForEach(discoveries) { discovery in discoveryCard(discovery) }
                    }
                case .changes:
                    let patterns = curatedPatterns.filter { matchesSearch($0.title, $0.description, $0.associatedMetrics.joined(separator: " ")) }
                    if patterns.isEmpty {
                        compactEmpty("No clear changes yet", icon: section.icon,
                                     detail: exploreSearchText.isEmpty
                                        ? "More consistent tracking gives Clove more history to compare."
                                        : "Try a different metric or phrase.")
                    } else {
                        ForEach(patterns) { insight in patternCard(insight) }
                    }
                case .flares:
                    flareContent
                case .cycles:
                    cycleContent
                case .baselines:
                    baselineContent
                }
            }
            .padding(CloveSpacing.large).padding(.bottom, 80)
        }
        .background(CloveColors.background.ignoresSafeArea())
        .navigationTitle(section.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { exploreSearchText = "" }
    }

    private var exploreSearchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").foregroundStyle(CloveColors.secondaryText)
            TextField("Search this section", text: $exploreSearchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !exploreSearchText.isEmpty {
                Button { exploreSearchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(CloveColors.secondaryText)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 12).padding(.vertical, 11)
        .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
    }

    private func matchesSearch(_ values: String...) -> Bool {
        let query = exploreSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || values.joined(separator: " ").localizedCaseInsensitiveContains(query)
    }

    @ViewBuilder private var flareContent: some View {
        if let source = viewModel.contextAnalysis?.flareComparisons, !source.isEmpty {
            let comparisons = source.sorted {
                normalizedMagnitude(metricID: $0.metricID, difference: $0.difference)
                    > normalizedMagnitude(metricID: $1.metricID, difference: $1.difference)
            }
            ForEach(comparisons.filter { matchesSearch($0.metricName, flareSummary($0)) }) { comparison in
                VStack(alignment: .leading, spacing: 7) {
                    Text(comparison.metricName).font(.headline)
                    Text(flareSummary(comparison)).font(.subheadline)
                    Text("Compared \(comparison.flareDayCount) flare days with \(comparison.nonFlareDayCount) other days")
                        .font(.caption).foregroundStyle(CloveColors.secondaryText)
                }.cardStyle()
            }
            limitationsFooter("These comparisons describe recorded flare days. They do not establish a cause or diagnose a condition.")
        } else {
            compactEmpty("Not enough flare comparisons", icon: "waveform.path.ecg",
                         detail: "Mark at least three flare days and track at least three other days to compare them.")
        }
    }

    @ViewBuilder private var cycleContent: some View {
        if let summaries = viewModel.contextAnalysis?.phaseSummaries, !summaries.isEmpty {
            ForEach(CyclePhase.allCases, id: \.self) { phase in
                let matches = summaries.filter { $0.phase == phase && matchesSearch($0.metricName, cycleSummary($0), phase.rawValue) }.sorted {
                    normalizedMagnitude(metricID: $0.metricID, difference: $0.differenceFromPersonalMean)
                        > normalizedMagnitude(metricID: $1.metricID, difference: $1.differenceFromPersonalMean)
                }
                if !matches.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(phase.rawValue).font(.headline).foregroundStyle(Color.pink)
                        ForEach(matches.prefix(4)) { summary in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(summary.metricName).font(.subheadline.bold())
                                Text(cycleSummary(summary)).font(.caption).foregroundStyle(CloveColors.secondaryText)
                            }
                            if summary.id != matches.prefix(4).last?.id { Divider() }
                        }
                        if matches.count > 4 {
                            Text("+ \(matches.count - 4) more recorded patterns")
                                .font(.caption.bold()).foregroundStyle(CloveColors.secondaryText)
                        }
                    }.cardStyle()
                }
            }
            limitationsFooter("Cycle phases are estimated only between explicitly recorded cycle starts.")
        } else {
            compactEmpty("Not enough repeated cycle data", icon: "calendar.badge.clock",
                         detail: "Record at least three cycle starts and the same metric during two complete cycles.")
        }
    }

    @ViewBuilder private var baselineContent: some View {
        if viewModel.baselines.isEmpty {
            compactEmpty("No qualified comparisons yet", icon: "scope",
                         detail: "Clove needs 28 earlier and 7 recent recordings for a metric.")
        } else {
            if atypicalBaselines.isEmpty {
                compactEmpty("Your recent metrics are within their usual ranges", icon: "checkmark.circle",
                             detail: "Nothing currently stands out from your own recorded history.")
            } else {
                ForEach(atypicalBaselines.filter { matchesSearch($0.metricName, baselineSummary($0)) }) { baseline in baselineCard(baseline) }
            }
            if !typicalBaselines.isEmpty {
                DisclosureGroup {
                    VStack(spacing: 10) {
                        ForEach(typicalBaselines.filter { matchesSearch($0.metricName) }) { baseline in
                            HStack {
                                Text(baseline.metricName).font(.subheadline)
                                Spacer()
                                Text("Within usual").font(.caption.bold()).foregroundStyle(.green)
                            }
                        }
                    }.padding(.top, 10)
                } label: {
                    Label("\(typicalBaselines.count) metrics within your usual range", systemImage: "checkmark.circle")
                        .font(.subheadline.bold()).foregroundStyle(.green)
                }
                .cardStyle()
            }
            limitationsFooter("Higher or lower only means different from your usual pattern—not automatically better or worse.")
        }
    }

    private func baselineCard(_ baseline: PersonalBaseline) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(baseline.metricName).font(.headline)
                Spacer()
                Text(baselineStatus(baseline)).font(.caption.bold())
                    .foregroundStyle(Theme.shared.accent)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Theme.shared.accent.opacity(0.12), in: Capsule())
            }
            Text(baselineSummary(baseline)).font(.subheadline)
            Text("Recent: \(plainNumber(baseline.recentValue)) · Usual: \(plainNumber(baseline.center))")
                .font(.caption).foregroundStyle(CloveColors.secondaryText)
        }.cardStyle()
    }

    private func limitationsFooter(_ text: String) -> some View {
        Label(text, systemImage: "info.circle")
            .font(.caption).foregroundStyle(CloveColors.secondaryText)
            .padding(.top, 4)
    }

    private func normalizedMagnitude(metricID: MetricID, difference: Double) -> Double {
        guard let definition = viewModel.dataset?.definitions.first(where: { $0.id == metricID }) else {
            return abs(difference)
        }
        switch definition.domain {
        case .numeric(let range):
            return abs(difference) / max(0.1, range.upperBound - range.lowerBound)
        case .nonNegative, .categories, .unrestricted:
            let values = viewModel.dataset?.observations(for: metricID).compactMap { observation -> Double? in
                guard case .observed(let value) = observation.state else { return nil }
                return value.numericValue
            } ?? []
            let span = (values.max() ?? 0) - (values.min() ?? 0)
            return abs(difference) / max(1, span)
        }
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
                Text(evidence.compactSummary)
                    .font(.caption).foregroundStyle(CloveColors.secondaryText)
                DisclosureGroup("Evidence details") {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(evidence.whyText)
                        ForEach(evidence.limitations, id: \.self) { Text("• \($0)") }
                    }
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)
                    .padding(.top, 5)
                }
                .font(.caption.bold())
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

    @ViewBuilder private var watching: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
            sectionHeading("Saved findings", caption: "Signals you chose to keep nearby")
            if savedDiscoveries.isEmpty && savedPatterns.isEmpty {
                compactEmpty("No saved findings", icon: "bookmark",
                             detail: "Save a connection or change and it will appear here.")
            } else {
                ForEach(savedDiscoveries) { discovery in discoveryCard(discovery) }
                ForEach(savedPatterns) { insight in patternCard(insight) }
            }

            HStack(alignment: .bottom) {
                sectionHeading("Your questions", caption: "Personal ideas you want to revisit")
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
            .padding(CloveSpacing.large).padding(.bottom, 80)
        }
        .background(CloveColors.background.ignoresSafeArea())
        .navigationTitle("Watching")
        .navigationBarTitleDisplayMode(.inline)
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
