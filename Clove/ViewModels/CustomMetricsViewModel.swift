import SwiftUI

@MainActor @Observable
final class CustomMetricsViewModel {
    var definitions: [CustomMetricDefinition] = []
    var errorMessage: String?
    private let repository: any CustomMetricsRepositoryProtocol
    init(repository: any CustomMetricsRepositoryProtocol = CustomMetricsRepo.shared) { self.repository = repository }
    func load() {
        do { definitions = try repository.definitions(); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }
    func save(_ definition: CustomMetricDefinition) throws {
        try repository.saveDefinition(definition)
        definitions = try repository.definitions()
    }
    func update(_ definition: CustomMetricDefinition) {
        do { try save(definition); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }
    func move(from source: IndexSet, to destination: Int) {
        var items = definitions.filter { $0.archivedAt == nil }
        items.move(fromOffsets: source, toOffset: destination)
        do { try repository.reorder(items.map(\.id)); load() }
        catch { errorMessage = error.localizedDescription }
    }
    func hasHistory(_ definition: CustomMetricDefinition) throws -> Bool { try repository.hasHistory(definition.id) }
}
