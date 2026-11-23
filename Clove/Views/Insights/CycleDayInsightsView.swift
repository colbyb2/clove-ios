import SwiftUI
import Charts

struct CycleDayInsightsView: View {
    let dataset: AnalyticsDataset
    let entries: [Cycle]
    @State private var selectedMetric = ""
    @State private var showingMeasurements = false
    @State private var showingDayDetails = false
    @State private var scrollDay = 0

    private var metrics: [MetricDefinition] {
        dataset.definitions.filter { definition in
            definition.source != .cycleEntries && definition.measurementLevel != .categorical &&
            definition.measurementLevel != .event && recordedDays(for: definition) > 0
        }.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var definition: MetricDefinition? {
        metrics.first { $0.id.rawValue == selectedMetric } ??
            metrics.first { $0.id == MetricCatalog.painLevel.id } ?? metrics.first
    }

    private var analysis: CycleDayAnalysis {
        CycleDayAnalysisEngine().analyze(
            observations: definition.map { dataset.observations(for: $0.id) } ?? [],
            entries: entries, interval: dataset.interval, binary: definition?.measurementLevel == .binary)
    }

    private var tint: Color { definition.map { MetricPresentation.tint(for: $0) } ?? Theme.shared.accent }
    private var dayDomain: ClosedRange<Int> {
        max(0, (analysis.points.first?.day ?? 1) - 1)...max(2, (analysis.points.last?.day ?? 1) + 1)
    }
    private var visibleDays: Int { min(30, max(7, analysis.points.count + 1)) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                header
                if let definition {
                    measurementSelector(definition)
                    if analysis.completedCycleCount == 0 {
                        emptyCard(title: "Start with two period starts", icon: "calendar.badge.plus",
                            detail: "Mark Period Started on the first day of two periods to define a completed cycle.",
                            hint: "Already tracking? Choose a wider date range on Insights to include past cycles.")
                    } else {
                        results
                    }
                } else {
                    emptyCard(title: "Add a measurement", icon: "chart.bar",
                        detail: "Record symptoms or health measurements to compare them with your cycle.",
                        hint: "Your measurements will appear here once you log them.")
                }
                DisclosureGroup("About these comparisons") {
                    Text("Day 1 is each marked period start. Only recorded measurements within completed cycles and the selected date range are included. Gaps are unknown, including days without bowel movement entries. Suspected ovulation reflects your signs or testing; these comparisons do not confirm ovulation or predict fertility.")
                        .font(.caption).foregroundStyle(CloveColors.secondaryText).padding(.top, 8)
                }
                .font(.subheadline).tint(CloveColors.secondaryText)
            }
            .padding(CloveSpacing.large)
            .padding(.bottom, 30)
        }
        .background(CloveColors.background)
        .navigationTitle("Cycle Insights")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingMeasurements) {
            CycleMeasurementPicker(metrics: metrics, selectedID: definition?.id.rawValue ?? "",
                recordedDays: recordedDays) { metric in
                selectedMetric = metric.id.rawValue
                showingDayDetails = false
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Explore patterns across your cycles")
                .font(.title3.weight(.semibold)).foregroundStyle(CloveColors.primaryText)
            Label(dataset.interval.start.formatted(date: .abbreviated, time: .omitted) + " – " +
                  dataset.interval.end.addingTimeInterval(-1).formatted(date: .abbreviated, time: .omitted),
                  systemImage: "calendar")
                .font(.caption).foregroundStyle(CloveColors.secondaryText)
        }
    }

    private func measurementSelector(_ metric: MetricDefinition) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COMPARE A MEASUREMENT")
                .font(.caption.weight(.semibold)).tracking(0.7).foregroundStyle(CloveColors.secondaryText)
            Button { showingMeasurements = true } label: {
                HStack(spacing: 12) {
                    CycleMeasurementIcon(metric: metric)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(metric.displayName).font(.headline).foregroundStyle(CloveColors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(recordedDays(for: metric)) recorded days in this range")
                            .font(.caption).foregroundStyle(CloveColors.secondaryText)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(tint)
                        .frame(width: 34, height: 34)
                        .background(tint.opacity(0.1), in: Circle())
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(CloveColors.card, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(tint.opacity(0.25), lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Measurement: \(metric.displayName)")
            .accessibilityHint("Choose another measurement to compare with your cycle")
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                summaryStat(value: analysis.completedCycleCount.formatted(), title: "Completed cycles", icon: "arrow.triangle.2.circlepath", color: .pink)
                summaryStat(value: analysis.points.reduce(0) { $0 + $1.observationCount }.formatted(), title: "Recorded days", icon: "checkmark.circle", color: tint)
            }
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Across cycle days", detail: "Average · \(unitLabel)", icon: "chart.bar.xaxis", color: tint)
                if analysis.points.contains(where: { $0.mean != nil }) {
                    measurementChart
                    Text("Swipe across the chart to explore longer cycles. Missing days stay blank.")
                        .font(.caption).foregroundStyle(CloveColors.secondaryText)
                } else {
                    Text("No recorded values for this measurement overlap the completed cycles in this range.")
                        .font(.subheadline).foregroundStyle(CloveColors.secondaryText)
                }
            }.cycleAnalysisCard()
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Cycle observations", detail: "Recorded flow and signs by cycle day", icon: "sparkles", color: .pink)
                if analysis.points.contains(where: { $0.flowCount + $0.noFlowCount + $0.fertilityCount + $0.ovulationCount > 0 }) {
                    signsChart
                    Text("Each marker means an observation was recorded in at least one cycle.")
                        .font(.caption).foregroundStyle(CloveColors.secondaryText)
                } else {
                    Text("Log flow or optional cycle signs to see them alongside your measurements.")
                        .font(.subheadline).foregroundStyle(CloveColors.secondaryText)
                }
            }.cycleAnalysisCard()
            flowComparison
            DisclosureGroup(isExpanded: $showingDayDetails) {
                VStack(spacing: 12) {
                    Text("Counts show how many cycles contributed a recorded measurement. One cycle describes that cycle only.")
                        .font(.caption).foregroundStyle(CloveColors.secondaryText)
                    ForEach(analysis.points) { point in
                        VStack(alignment: .leading, spacing: 5) {
                            Divider()
                            HStack {
                                Text("Day \(point.day)").font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(point.mean.map(formatted) ?? "No data").font(.subheadline)
                            }
                            Text("\(point.observationCount) of \(point.eligibleCycleCount) cycles recorded")
                                .font(.caption).foregroundStyle(CloveColors.secondaryText)
                            let signs = markers(point)
                            if !signs.isEmpty { Text(signs).font(.caption).foregroundStyle(.pink) }
                        }
                    }
                }.padding(.top, 12)
            } label: {
                Label("Day details", systemImage: "list.bullet").font(.subheadline.weight(.semibold))
            }
            .tint(CloveColors.primaryText).cycleAnalysisCard()
        }
    }

    private var measurementChart: some View {
        Chart(analysis.points) { point in
            if let mean = point.mean {
                BarMark(x: .value("Cycle day", point.day), y: .value(unitLabel, displayValue(mean)))
                    .cornerRadius(3).foregroundStyle(tint.gradient)
                    .accessibilityLabel("Cycle day \(point.day)")
                    .accessibilityValue("\(formatted(mean)), \(point.observationCount) observations")
            }
        }
        .chartXScale(domain: dayDomain).chartXAxisLabel("Cycle day")
        .chartScrollableAxes(.horizontal).chartXVisibleDomain(length: visibleDays)
        .chartScrollPosition(x: $scrollDay)
        .frame(height: 220)
    }

    private var signsChart: some View {
        Chart(analysis.points) { point in
            if point.flowCount > 0 {
                PointMark(x: .value("Cycle day", point.day), y: .value("Observation", "Flow"))
                    .foregroundStyle(.pink).symbolSize(35)
                    .accessibilityLabel("Day \(point.day): flow in \(point.flowCount) cycles")
            }
            if point.noFlowCount > 0 {
                PointMark(x: .value("Cycle day", point.day), y: .value("Observation", "No flow"))
                    .foregroundStyle(.gray).symbolSize(35)
                    .accessibilityLabel("Day \(point.day): no flow in \(point.noFlowCount) cycles")
            }
            if point.fertilityCount > 0 {
                PointMark(x: .value("Cycle day", point.day), y: .value("Observation", "Fertility signs"))
                    .foregroundStyle(.purple).symbolSize(35)
                    .accessibilityLabel("Day \(point.day): fertility signs in \(point.fertilityCount) cycles")
            }
            if point.ovulationCount > 0 {
                PointMark(x: .value("Cycle day", point.day), y: .value("Observation", "Suspected ovulation"))
                    .foregroundStyle(.orange).symbolSize(35)
                    .accessibilityLabel("Day \(point.day): suspected ovulation in \(point.ovulationCount) cycles")
            }
        }
        .chartXScale(domain: dayDomain)
        .chartYScale(domain: ["Flow", "No flow", "Fertility signs", "Suspected ovulation"])
        .chartXAxisLabel("Cycle day").chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visibleDays).chartScrollPosition(x: $scrollDay).frame(height: 160)
    }

    private var flowComparison: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Flow & no flow", detail: "Average \(definition?.displayName.lowercased() ?? "value") on recorded days", icon: "drop", color: .pink)
            HStack(alignment: .top, spacing: 12) {
                flowStat(hasFlow: true)
                flowStat(hasFlow: false)
            }
            if analysis.flowGroups.count < 2 {
                Text("Record this measurement on both flow and explicit no-flow days to compare them.")
                    .font(.caption).foregroundStyle(CloveColors.secondaryText)
            }
        }.cycleAnalysisCard()
    }

    private func flowStat(hasFlow: Bool) -> some View {
        let group = analysis.flowGroups.first { $0.hasFlow == hasFlow }
        return VStack(alignment: .leading, spacing: 6) {
            Label(hasFlow ? "Flow" : "No flow", systemImage: hasFlow ? "drop.fill" : "circle")
                .font(.caption.weight(.semibold)).foregroundStyle(hasFlow ? Color.pink : CloveColors.secondaryText)
            Text(group.map { formatted($0.mean) } ?? "—").font(.title2.weight(.semibold))
            Text(group.map { "\($0.observationCount) recorded days" } ?? "No matching days")
                .font(.caption).foregroundStyle(CloveColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(CloveColors.background, in: RoundedRectangle(cornerRadius: 12))
    }

    private func summaryStat(value: String, title: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.title2.weight(.semibold))
            Text(title).font(.caption).foregroundStyle(CloveColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading).cycleAnalysisCard()
    }

    private func sectionHeader(_ title: String, detail: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(CloveColors.secondaryText)
            }
        }
    }

    private func emptyCard(title: String, icon: String, detail: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(.pink)
                .frame(width: 48, height: 48).background(Color.pink.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(CloveColors.secondaryText)
            Label(hint, systemImage: "info.circle").font(.caption).foregroundStyle(CloveColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading).cycleAnalysisCard()
    }

    private func recordedDays(for metric: MetricDefinition) -> Int {
        dataset.observations(for: metric.id).filter {
            if case .observed(let value) = $0.state { return value.numericValue != nil }
            return false
        }.count
    }

    private var unitLabel: String {
        guard let definition else { return "Value" }
        if definition.measurementLevel == .binary { return "Recorded occurrence (%)" }
        switch definition.unit {
        case .score: return "Score"
        case .count: return "Count"
        case .percentage: return "%"
        case .fluidOunces: return HydrationPreferences.unit().symbol
        case .minutes: return "Minutes"
        case .custom(let symbol): return symbol
        case .category, .occurrence: return "Value"
        }
    }

    private func displayValue(_ number: Double) -> Double {
        definition?.unit == .fluidOunces
            ? (HydrationPreferences.unit() == .milliliters ? number * 29.5735 : number) : number
    }

    private func formatted(_ number: Double) -> String {
        displayValue(number).formatted(.number.precision(.fractionLength(0...1))) +
            (definition?.measurementLevel == .binary ? "%" : "")
    }

    private func markers(_ point: CycleDayPoint) -> String {
        var labels: [String] = []
        if point.flowCount > 0 { labels.append("Flow: \(point.flowCount)") }
        if point.noFlowCount > 0 { labels.append("No flow: \(point.noFlowCount)") }
        if point.fertilityCount > 0 { labels.append("Fertility signs: \(point.fertilityCount)") }
        if point.ovulationCount > 0 { labels.append("Suspected ovulation: \(point.ovulationCount)") }
        return labels.joined(separator: " · ")
    }
}

private struct CycleMeasurementPicker: View {
    @Environment(\.dismiss) private var dismiss
    let metrics: [MetricDefinition]
    let selectedID: String
    let recordedDays: (MetricDefinition) -> Int
    let onSelect: (MetricDefinition) -> Void
    @State private var search = ""

    private var filtered: [MetricDefinition] {
        metrics.filter { search.isEmpty || $0.displayName.localizedCaseInsensitiveContains(search) || cycleCategoryTitle($0.category).localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(MetricSemanticCategory.allCases, id: \.self) { category in
                    let matches = filtered.filter { $0.category == category }
                    if !matches.isEmpty {
                        Section(cycleCategoryTitle(category)) {
                            ForEach(matches) { metric in
                                Button {
                                    onSelect(metric)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        CycleMeasurementIcon(metric: metric)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(metric.displayName).font(.body.weight(.medium))
                                                .foregroundStyle(CloveColors.primaryText)
                                                .fixedSize(horizontal: false, vertical: true)
                                            Text("\(recordedDays(metric)) recorded days")
                                                .font(.caption).foregroundStyle(CloveColors.secondaryText)
                                        }
                                        Spacer(minLength: 6)
                                        if metric.id.rawValue == selectedID {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Theme.shared.accent).font(.title3)
                                        }
                                    }
                                    .padding(.vertical, 5).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityValue(metric.id.rawValue == selectedID ? "Selected" : "")
                                .listRowBackground(CloveColors.card)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(CloveColors.background)
            .searchable(text: $search, prompt: "Search measurements")
            .overlay {
                if filtered.isEmpty { ContentUnavailableView.search(text: search) }
            }
            .navigationTitle("Choose measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.large]).presentationDragIndicator(.visible)
    }
}

private struct CycleMeasurementIcon: View {
    let metric: MetricDefinition
    private var icon: String {
        switch metric.id {
        case MetricCatalog.painLevel.id: return "bolt.heart"
        case MetricCatalog.mood.id: return "face.smiling"
        case MetricCatalog.energyLevel.id: return "bolt.fill"
        case MetricCatalog.hydration.id: return "drop.fill"
        case MetricCatalog.bowelMovementFrequency.id: return "toilet"
        case MetricCatalog.flareDay.id: return "flame"
        case MetricCatalog.medicationAdherence.id: return "pills"
        default: return metric.category == .symptoms ? "waveform.path.ecg" : "chart.bar"
        }
    }
    var body: some View {
        Image(systemName: icon).font(.headline).foregroundStyle(MetricPresentation.tint(for: metric))
            .frame(width: 42, height: 42)
            .background(MetricPresentation.tint(for: metric).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)
    }
}

private func cycleCategoryTitle(_ category: MetricSemanticCategory) -> String {
    switch category {
    case .coreHealth: return "Health"
    case .symptoms: return "Symptoms"
    case .medications: return "Medications"
    case .lifestyle: return "Lifestyle"
    case .environmental: return "Environment"
    case .activities: return "Activities"
    case .meals: return "Meals"
    }
}

private extension View {
    func cycleAnalysisCard() -> some View {
        padding(16)
            .background(CloveColors.card, in: RoundedRectangle(cornerRadius: 18))
    }
}
