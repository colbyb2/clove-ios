import SwiftUI
import Charts

struct RelationshipResultsView: View {
    private struct ScatterCoordinate: Hashable {
        let factor: Double
        let outcome: Double
    }

    private struct ScatterBin: Identifiable {
        var id: ScatterCoordinate { coordinate }
        let coordinate: ScatterCoordinate
        let dayCount: Int
    }

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
                HStack(spacing: 8) {
                    resultBadge("\(estimate.strength) pattern", icon: "waveform.path")
                    resultBadge("\(estimate.sampleCount) matching days", icon: "calendar")
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
        let bins = scatterBins(from: analysis.alignment.pairs)
        let numericPairCount = bins.reduce(0) { $0 + $1.dayCount }
        let largestBin = max(1, bins.map { $0.dayCount }.max() ?? 1)
        return card {
            HStack {
                Text("\(analysis.factorDefinition.displayName) and \(analysis.outcomeDefinition.displayName)")
                    .font(.headline).foregroundStyle(CloveColors.primaryText)
                Spacer()
                Text("\(numericPairCount) days").font(.caption.bold()).foregroundStyle(Theme.shared.accent)
            }
            Text("Each bubble is one combination of the two values. Larger, darker bubbles mean that combination happened on more days.")
                .font(.caption).foregroundStyle(CloveColors.secondaryText)
            if numericPairCount > 0 {
                Chart(bins) { bin in
                    let density = Double(bin.dayCount) / Double(largestBin)
                    PointMark(
                        x: .value(analysis.factorDefinition.displayName, bin.coordinate.factor),
                        y: .value(analysis.outcomeDefinition.displayName, bin.coordinate.outcome)
                    )
                    .foregroundStyle(Theme.shared.accent.opacity(0.35 + density * 0.65))
                    .symbolSize(45 + min(190, Double(bin.dayCount - 1) * 28))
                }
                .frame(height: 220)
                .chartXAxisLabel(position: .bottom, alignment: .center) {
                    Text(analysis.factorDefinition.displayName).font(.caption.bold())
                }
                .chartYAxisLabel(position: .leading, alignment: .center) {
                    Text(analysis.outcomeDefinition.displayName).font(.caption.bold())
                }
                HStack(spacing: 16) {
                    Label("Fewer days", systemImage: "circle.fill")
                        .foregroundStyle(Theme.shared.accent.opacity(0.4))
                    Label("More days", systemImage: "circle.inset.filled")
                        .foregroundStyle(Theme.shared.accent)
                    Spacer()
                    Text("\(bins.count) value combinations")
                        .foregroundStyle(CloveColors.secondaryText)
                }
                .font(.caption2)
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

    private func scatterBins(from pairs: [AlignedMetricPair]) -> [ScatterBin] {
        var counts: [ScatterCoordinate: Int] = [:]
        for pair in pairs {
            guard let factor = pair.factor.numeric, let outcome = pair.outcome.numeric else { continue }
            counts[ScatterCoordinate(factor: factor, outcome: outcome), default: 0] += 1
        }
        return counts.map { ScatterBin(coordinate: $0.key, dayCount: $0.value) }
            .sorted {
                if $0.coordinate.factor == $1.coordinate.factor {
                    return $0.coordinate.outcome < $1.coordinate.outcome
                }
                return $0.coordinate.factor < $1.coordinate.factor
            }
    }

    private var groupedPlot: some View {
        let groups = Dictionary(grouping: analysis.alignment.pairs, by: { $0.factor.category })
        return card {
            Text("\(analysis.outcomeDefinition.displayName) across \(analysis.factorDefinition.displayName) groups")
                .font(.headline).foregroundStyle(CloveColors.primaryText)
            Text("Each bar shows the typical \(analysis.outcomeDefinition.displayName.lowercased()) value for one \(analysis.factorDefinition.displayName.lowercased()) group.")
                .font(.caption).foregroundStyle(CloveColors.secondaryText)
            Chart(groups.keys.sorted(), id: \.self) { group in
                let numeric = (groups[group] ?? []).compactMap { $0.outcome.numeric }
                let value = numeric.isEmpty ? Double((groups[group] ?? []).count) : numeric.reduce(0, +) / Double(numeric.count)
                BarMark(x: .value("Group", group), y: .value("Outcome", value)).foregroundStyle(Theme.shared.accent)
            }.frame(height: 220)
        }
    }

    private var eventPlot: some View {
        card {
            Text("\(analysis.outcomeDefinition.displayName) after \(analysis.factorDefinition.displayName)")
                .font(.headline).foregroundStyle(CloveColors.primaryText)
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
                Text("\(result.outcomeOffsetDays == 0 ? "Same day" : "Next day"): compared \(result.exposedCount) event days with \(result.controlCount) other days")
                    .font(.caption).foregroundStyle(CloveColors.secondaryText)
            }
        }
    }

    private func lagProfile(_ profile: LagRelationshipProfile) -> some View {
        let plottedPoints = profile.points.filter { $0.estimate.effect != nil }
        return card {
            Text("Does timing matter?").font(.headline).foregroundStyle(CloveColors.primaryText)
            if plottedPoints.count >= 2 {
                Text("Clove checked whether \(analysis.factorDefinition.displayName) tended to appear before, on the same day as, or after \(analysis.outcomeDefinition.displayName).")
                    .font(.subheadline).foregroundStyle(CloveColors.secondaryText)
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
                .chartXAxis {
                    AxisMarks(values: [-7, 0, 7]) { value in
                        AxisGridLine().foregroundStyle(CloveColors.secondaryText.opacity(0.2))
                        AxisTick()
                        AxisValueLabel {
                            if let day = value.as(Int.self) {
                                Text(day < 0 ? "\(analysis.outcomeDefinition.displayName) first" : day > 0 ? "\(analysis.factorDefinition.displayName) first" : "Same day")
                                    .font(.caption2)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [-1.0, 0.0, 1.0]) { value in
                        AxisGridLine().foregroundStyle(CloveColors.secondaryText.opacity(0.2))
                        AxisValueLabel {
                            if let strength = value.as(Double.self) {
                                Text(strength < 0 ? "Opposite" : strength > 0 ? "Together" : "No pattern")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                Text("Dots near the middle mean little or no consistent pattern. Dots farther above or below the middle indicate a clearer pattern.")
                    .font(.caption).foregroundStyle(CloveColors.secondaryText)
                if let best = profile.bestSupported {
                    Label(timingSummary(best), systemImage: "clock.badge.checkmark")
                        .font(.subheadline.bold()).foregroundStyle(CloveColors.primaryText)
                }
            } else {
                compactUnavailable("Not enough matching recorded days to compare timing yet.")
            }
            Label("This timing result is a clue to keep watching, not proof that one item causes the other.", systemImage: "info.circle")
                .font(.caption).foregroundStyle(.orange)
        }
    }

    private var coverage: some View {
        card {
            let coverage = analysis.alignment.coverage
            Text("How much data was compared?").font(.headline).foregroundStyle(CloveColors.primaryText)
            HStack(alignment: .firstTextBaseline) {
                Text("\(coverage.matchedDayCount) days")
                    .font(.title2.bold()).foregroundStyle(CloveColors.primaryText)
                Spacer()
                Text(coverage.matchedFraction.formatted(.percent.precision(.fractionLength(0))))
                    .font(.headline).foregroundStyle(Theme.shared.accent)
            }
            ProgressView(value: coverage.matchedFraction).tint(Theme.shared.accent)
            Text(coverageSummary(coverage))
                .font(.subheadline).foregroundStyle(CloveColors.secondaryText)

            DisclosureGroup("Data details") {
                VStack(alignment: .leading, spacing: 8) {
                    detailRow("Days in the selected range", value: coverage.eligibleDayCount)
                    detailRow("Days with \(analysis.factorDefinition.displayName)", value: coverage.factorObservedDayCount)
                    detailRow("Days with \(analysis.outcomeDefinition.displayName)", value: coverage.outcomeObservedDayCount)
                    detailRow("Days with both", value: coverage.matchedDayCount)
                    Text("Missing days were left out of the comparison. They were not changed to zero.")
                        .font(.caption).foregroundStyle(CloveColors.secondaryText)
                }
                .padding(.top, 8)
            }
            .font(.subheadline.bold())
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

    private func timingSummary(_ point: LagRelationshipPoint) -> String {
        if point.lagDays == 0 {
            return "The clearest timing pattern appeared on the same day."
        }
        if point.lagDays > 0 {
            return "The clearest pattern appeared when \(analysis.factorDefinition.displayName) came \(point.lagDays) days before \(analysis.outcomeDefinition.displayName)."
        }
        return "The clearest pattern appeared when \(analysis.outcomeDefinition.displayName) came \(-point.lagDays) days before \(analysis.factorDefinition.displayName)."
    }

    private func coverageSummary(_ coverage: PairAlignmentCoverage) -> String {
        if coverage.matchedDayCount == coverage.eligibleDayCount {
            return "Both \(analysis.factorDefinition.displayName) and \(analysis.outcomeDefinition.displayName) were available on every day in the selected range."
        }
        return "Both items were available on \(coverage.matchedDayCount) of \(coverage.eligibleDayCount) days. The other \(coverage.excludedDayCount) days could not be compared because one or both items were missing."
    }

    private func resultBadge(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.bold())
            .foregroundStyle(Theme.shared.accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Theme.shared.accent.opacity(0.12), in: Capsule())
    }

    private func detailRow(_ title: String, value: Int) -> some View {
        HStack {
            Text(title).foregroundStyle(CloveColors.secondaryText)
            Spacer()
            Text("\(value)").fontWeight(.semibold).foregroundStyle(CloveColors.primaryText)
        }
        .font(.caption)
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
