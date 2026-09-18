import SwiftUI

struct RepositoryErrorView: View {
    let title: String
    let error: RepositoryError
    let onRetry: () -> Void

    init(
        title: String = "We couldn't load your data",
        error: RepositoryError,
        onRetry: @escaping () -> Void
    ) {
        self.title = title
        self.error = error
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(CloveColors.error)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                    Text("Your existing data is still safe. Try loading it again.")
                        .font(.subheadline)
                        .foregroundStyle(CloveColors.secondaryText)
                }
            }

            HStack(spacing: 12) {
                Button("Try Again", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.shared.accent)

                ShareLink(item: error.exportText) {
                    Label("Share Details", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .tint(Theme.shared.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CloveSpacing.medium)
        .background(CloveColors.error.opacity(0.08), in: RoundedRectangle(cornerRadius: CloveCorners.medium))
        .overlay {
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .stroke(CloveColors.error.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

