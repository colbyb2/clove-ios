import Foundation

extension MetricCatalog {
    /// Resolves every provider currently registered by `MetricRegistry` to its catalog definition.
    static func definition(for provider: any MetricProvider) -> MetricDefinition? {
        if let definition = staticDefinitionsByID[MetricID(rawValue: provider.id)] {
            return definition
        }

        switch provider {
        case let symptom as SymptomMetricProvider:
            let isBinary: Bool
            if case .binary = symptom.dataType {
                isBinary = true
            } else {
                isBinary = false
            }
            return self.symptom(
                id: MetricID(rawValue: symptom.id),
                name: symptom.symptomName,
                isBinary: isBinary
            )

        case let medication as MedicationMetricProvider:
            return medicationOccurrence(
                id: MetricID(rawValue: medication.id),
                name: medication.medicationName
            )

        case let activity as ActivityMetricProvider:
            return activityOccurrence(
                id: MetricID(rawValue: activity.id),
                name: activity.activityName
            )

        case let meal as MealMetricProvider:
            return mealOccurrence(
                id: MetricID(rawValue: meal.id),
                name: meal.mealName
            )

        default:
            return nil
        }
    }
}

extension MetricProvider {
    /// Authoritative definition when this provider is represented in the Phase 1 catalog.
    var catalogMetricDefinition: MetricDefinition? {
        MetricCatalog.definition(for: self)
    }
}

enum MetricCatalogCompatibilityChecks {
    static func failures(for providers: [any MetricProvider]) -> [String] {
        providers.compactMap { provider in
            guard let definition = MetricCatalog.definition(for: provider) else {
                return "No catalog definition for provider \(provider.id)"
            }
            guard definition.isValid else {
                return "Invalid catalog definition for provider \(provider.id): \(definition.validationIssues)"
            }
            return nil
        }
    }

    static func assertAllProvidersMapped(
        _ providers: [any MetricProvider],
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        let messages = failures(for: providers)
        precondition(messages.isEmpty, messages.joined(separator: "\n"), file: file, line: line)
    }
}
