import SwiftUI

/// Environment key for dependency injection
private struct DependencyContainerKey: EnvironmentKey {
    /// Default value uses the production dependency container
    static let defaultValue: DependencyContaining = DependencyContainer.shared
}

extension EnvironmentValues {
    /// Access to the dependency container through the environment
    /// Can be overridden in previews and tests with mock implementations
    var dependencies: DependencyContaining {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}
