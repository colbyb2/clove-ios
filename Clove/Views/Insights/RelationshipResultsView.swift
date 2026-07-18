import SwiftUI
import Charts

struct RelationshipResultsView: View {
    let analysis: CorrelationAnalysis
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.large) {
            summary
            appropriatePlot
            if let profile = analysis.lagProfile { lagProfile(profile) }
            coverage
            technicalDetails
            dailyDrillDown
            Button(action: onSave) { Label("Save Analysis", systemImage: "bookmark") }
                .buttonStyle(.borderedProminent).tint(Theme.shared.accent)
        }
    }

    private var summary: some View {
        card {
            Text("What the data suggests").font(.title3.bold()).foregroundStyle(CloveColors.primaryText)
            ForEach(analysis.insights, id: \.self) { insight in
                Label(insight, systemImage: "sparkles")
                    .font(CloveFonts.body()).foregroundStyle(CloveColors.secondaryText)
            }
            if let estimate = analysis.estimate {
                HStack {
                    evidenceItem("Effect", estimate.effect.map { String(format: "%.2f", $0) } ?? "—")
                    evidenceItem("Evidence", estimate.evidenceQuality.rawValue)
                    evidenceItem("Matched", "\(estimate.sampleCount)d")
                }
            }
        }
    }

    @ViewBuilder private var appropriatePlot: some View {
        if !analysis.eventOutcomes.isEmpty { eventPlot }
        else if analysis.factorDefinition.measurementLevel == .categorical || analysis.outcomeDefinition.measurementLevel == .categorical ||
                    analysis.factorDefinition.measurementLevel == .binary || analysis.outcomeDefinition.measurementLevel == .binary { groupedPlot }
        else { scatterPlot }
    }

    private var scatterPlot: some View {
        let numericPairCount = analysis.alignment.pairs.filter {
            $0.factor.numeric != nil && $0.outcome.numeric != nil
        }.count
        return card {
            HStack {
                Text("\(analysis.factorDefinition.displayName) and \(analysis.outcomeDefinition.displayName)")
                    .font(.headline).foregroundStyle(CloveColors.primaryText)
                Spacer()
                Text("\(numericPairCount) days").font(.caption.bold()).foregroundStyle(Theme.shared.accent)
            }
            Text("Each dot is one day when both metrics were recorded.")
                .font(.caption).foregroundStyle(CloveColors.secondaryText)
            if numericPairCount > 0 {
                Chart(Array(analysis.alignment.pairs.enumerated()), id: \.offset) { _, pair in
                    if let x = pair.factor.numeric, let y = pair.outcome.numeric {
                        PointMark(
                            x: .value(analysis.factorDefinition.displayName, x),
                            y: .value(analysis.outcomeDefinition.displayName, y)
                        )
                        .foregroundStyle(Theme.shared.accent.opacity(0.8))
                        .symbolSize(55)
                    }
                }
                .frame(height: 220)
                .chartXAxisLabel(position: .bottom, alignment: .center) {
                    Text(analysis.factorDefinition.displayName).font(.caption.bold())
                }
                .chartYAxisLabel(position: .leading, alignment: .center) {
                    Text(analysis.outcomeDefinition.displayName).font(.caption.bold())
                }
                if numericPairCount < max(analysis.factorDefinition.minimumSamples.relationship,
                                          analysis.outcomeDefinition.minimumSamples.relationship) {
                    Label("Too few matched days for a dependable relationship estimate.", systemImage: "exclamationmark.circle")
                        .font(.caption).foregroundStyle(.orange)
                }
            } else {
                compactUnavailable("These metrics do not have numeric values on the same recorded days.")
            }
        }
    }

    private var groupedPlot: some View {
        let groups = Dictionary(grouping: analysis.alignment.pairs, by: { $0.factor.category })
        return card {
            Text("Outcome by Factor Group").font(.headline).foregroundStyle(CloveColors.primaryText)
            Chart(groups.keys.sorted(), id: \.self) { group in
                let numeric = (groups[group] ?? []).compactMap { $0.outcome.numeric }
                let value = numeric.isEmpty ? Double((groups[group] ?? []).count) : numeric.reduce(0, +) / Double(numeric.count)
                BarMark(x: .value("Group", group), y: .value("Outcome", value)).foregroundStyle(Theme.shared.accent)
            }.frame(height: 220)
        }
    }

    private var eventPlot: some View {
        card {
            Text("Outcome After Event").font(.headline).foregroundStyle(CloveColors.primaryText)
            Chart(analysis.eventOutcomes, id: \.outcomeOffsetDays) { result in
                if let exposed = result.exposedMean {
                    BarMark(x: .value("Window", result.outcomeOffsetDays == 0 ? "Same day" : "Next day"), y: .value("Average", exposed))
                        .foregroundStyle(Theme.shared.accent)
                }
                if let control = result.controlMean {
                    BarMark(x: .value("Window", result.outcomeOffsetDays == 0 ? "Same day" : "Next day"), y: .value("Average", control))
                        .foregroundStyle(CloveColors.secondaryText).position(by: .value("Group", "Control"))
                }
            }.frame(height: 220)
            ForEach(analysis.eventOutcomes, id: \.outcomeOffsetDays) { result in
                Text("\(result.outcomeOffsetDays == 0 ? "Same day" : "Next day"): \(result.exposedCount) exposed, \(result.controlCount) control days")
                    .font(.caption).foregroundStyle(CloveColors.secondaryText)
            }
        }
    }

    private func lagProfile(_ profile: LagRelationshipProfile) -> some View {
        let plottedPoints = profile.points.filter { $0.estimate.effect != nil }
        return card {
            Text("Timing Explorer").font(.headline).foregroundStyle(CloveColors.primaryText)
            if plottedPoints.count >= 2 {
                Text("Checks whether the factor was recorded before, on, or after the outcome.")
                    .font(.caption).foregroundStyle(CloveColors.secondaryText)
                Chart {
                    RuleMark(y: .value("No relationship", 0))
                        .foregroundStyle(CloveColors.secondaryText.opacity(0.4))
                    ForEach(plottedPoints) { point in
                        LineMark(x: .value("Days apart", point.lagDays), y: .value("Relationship", point.estimate.effect ?? 0))
                            .foregroundStyle(Theme.shared.accent)
                        PointMark(x: .value("Days apart", point.lagDays), y: .value("Relationship", point.estimate.effect ?? 0))
                            .foregroundStyle(Theme.shared.accent)
                    }
                }
                .frame(height: 180)
                .chartXAxisLabel("Days apart")
                .chartYAxisLabel("Relationship strength")
                Text("Left: outcome first  •  0: same day  •  Right: factor first")
                    .font(.caption2).foregroundStyle(CloveColors.secondaryText)
                if let best = profile.bestSupported {
                    Text(best.lagDays == 0 ? "Strongest supported pattern is on the same day." :
                         (best.lagDays > 0 ? "Strongest explored pattern: factor \(best.lagDays) days before outcome." : "Strongest explored pattern: outcome \(-best.lagDays) days before factor."))
                        .font(.caption).foregroundStyle(CloveColors.secondaryText)
                }
            } else {
                compactUnavailable("Not enough matching recorded days to compare timing yet.")
            }
            if let limitation = profile.limitations.first(where: { $0.contains("explored") }) {
                Text(limitation).font(.caption2).foregroundStyle(.orange)
            }
        }
    }

    private var coverage: some View {
        card {
            Text("Coverage").font(.headline).foregroundStyle(CloveColors.primaryText)
            let coverage = analysis.alignment.coverage
            HStack {
                evidenceItem("Eligible", "\(coverage.eligibleDayCount)")
                evidenceItem("Factor", "\(coverage.factorObservedDayCount)")
                evidenceItem("Outcome", "\(coverage.outcomeObservedDayCount)")
                evidenceItem("Matched", "\(coverage.matchedDayCount)")
            }
            ProgressView(value: coverage.matchedFraction).tint(Theme.shared.accent)
            Text("\(coverage.excludedDayCount) eligible days were excluded because both values were not recorded. Gaps were not changed to zero.")
                .font(.caption).foregroundStyle(CloveColors.secondaryText)
        }
    }

    private var technicalDetails: some View {
        card {
            DisclosureGroup("Method & limitations") {
                VStack(alignment: .leading, spacing: 8) {
                    if let estimate = analysis.estimate {
                        Text("Method: \(estimate.method.displayName)")
                        if let interval = estimate.confidenceInterval { Text("95% interval: \(interval.lowerBound.formatted(.number.precision(.fractionLength(2)))) to \(interval.upperBound.formatted(.number.precision(.fractionLength(2))))") }
                        if let p = estimate.pValue { Text("Two-sided p-value: \(p.formatted(.number.precision(.fractionLength(3))))") }
                        ForEach(estimate.limitations, id: \.self) { Text("• \($0)") }
                    } else if let event = analysis.eventOutcomes.first {
                        ForEach(event.limitations, id: \.self) { Text("• \($0)") }
                    }
                }.font(.caption).foregroundStyle(CloveColors.secondaryText).padding(.top, 8)
            }
        }
    }

    private var dailyDrillDown: some View {
        card {
            DisclosureGroup("Matching days (\(analysis.alignment.pairs.count))") {
                ForEach(analysis.alignment.pairs.prefix(40)) { pair in
                    HStack {
                        Text(pair.factorDay.formatted(date: .abbreviated, time: .omitted))
                        Spacer()
                        Text("\(pair.factor.category) → \(pair.outcome.category)")
                    }.font(.caption).foregroundStyle(CloveColors.secondaryText).padding(.vertical, 3)
                }
            }
        }
    }

    private func evidenceItem(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(CloveColors.secondaryText)
            Text(value).font(.subheadline.bold()).foregroundStyle(CloveColors.primaryText)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactUnavailable(_ message: String) -> some View {
        HStack(spacing: CloveSpacing.small) {
            Image(systemName: "chart.xyaxis.line").foregroundStyle(CloveColors.secondaryText)
            Text(message).font(.caption).foregroundStyle(CloveColors.secondaryText)
        }
        .padding(CloveSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CloveColors.background, in: RoundedRectangle(cornerRadius: CloveCorners.small))
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) { content() }
            .padding(CloveSpacing.large).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: CloveCorners.medium).fill(CloveColors.card))
    }
}
