import SwiftUI

// MARK: - Models

struct ChangelogVersion: Identifiable {
    let id = UUID()
    let version: String
    let date: String
    let changes: [ChangelogItem]
}

struct ChangelogItem: Identifiable {
    let id = UUID()
    let type: ChangeType
    let description: String

    enum ChangeType {
        case new
        case improvement
        case bugfix

        var icon: String {
            switch self {
            case .new: return "sparkles"
            case .improvement: return "arrow.up.circle.fill"
            case .bugfix: return "wrench.and.screwdriver.fill"
            }
        }

        var color: Color {
            switch self {
            case .new: return .green
            case .improvement: return Theme.shared.accent
            case .bugfix: return .orange
            }
        }

        var label: String {
            switch self {
            case .new: return "New"
            case .improvement: return "Improved"
            case .bugfix: return "Fixed"
            }
        }
    }
}

// MARK: - Changelog Data

class ChangelogData {
    static let versions: [ChangelogVersion] = [
        ChangelogVersion(
            version: "1.5.0",
            date: "February 2026",
            changes: [
                ChangelogItem(type: .new, description: "In App Rating System"),
                ChangelogItem(type: .improvement, description: "Overhaul Meals and Activities Feature"),
                ChangelogItem(type: .new, description: "Cycle and Period Tracking Feature"),
                ChangelogItem(type: .improvement, description: "UI Improvements")
            ]
        ),
        ChangelogVersion(
            version: "1.4.0",
            date: "December 2025",
            changes: [
                ChangelogItem(type: .bugfix, description: "Fixed feature selection bug: Missing option."),
                ChangelogItem(type: .new, description: "Added expanded chart view, opens on tap."),
                ChangelogItem(type: .improvement, description: "Improved Toast System"),
                ChangelogItem(type: .improvement, description: "Bar chart appearance updated for better inference + legend added."),
                ChangelogItem(type: .improvement, description: "Small UI Enancements"),
                ChangelogItem(type: .new, description: "iOS 26 Support"),
                ChangelogItem(type: .new, description: "Added Search Tab"),
                ChangelogItem(type: .improvement, description: "Find all symptoms included inactive ones no longer being tracked."),
                ChangelogItem(type: .improvement, description: "Slider gestures modified to stop vertical scroll interference"),
                ChangelogItem(type: .new, description: "One time symptoms can be added, as well as a new rating scale Yes/No."),
                ChangelogItem(type: .improvement, description: "Revamped calendar UI."),
                ChangelogItem(type: .new, description: "Select recent metric in explorer."),
                ChangelogItem(type: .improvement, description: "Upgraded correlation view for better user experience."),
            ]
        )
    ]
}

// MARK: - Changelog View

struct ChangelogView: View {
    @State private var expandedVersions: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(spacing: CloveSpacing.large) {
                // Header
                VStack(spacing: CloveSpacing.small) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.shared.accent)

                    Text("What's New")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(CloveColors.primaryText)

                    Text("See what's changed in each version of Clove")
                        .font(CloveFonts.body())
                        .foregroundStyle(CloveColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, CloveSpacing.large)
                .padding(.horizontal, CloveSpacing.large)

                // Version list
                VStack(spacing: CloveSpacing.medium) {
                    ForEach(ChangelogData.versions) { version in
                        VersionCard(
                            version: version,
                            isExpanded: expandedVersions.contains(version.version)
                        ) {
                            toggleExpansion(for: version.version)
                        }
                    }
                }
                .padding(.horizontal, CloveSpacing.large)
                .padding(.bottom, CloveSpacing.large)
            }
        }
        .background(CloveColors.background)
        .navigationTitle("Changelog")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Auto-expand the first (most recent) version
            if let firstVersion = ChangelogData.versions.first {
                expandedVersions.insert(firstVersion.version)
            }
        }
    }

    private func toggleExpansion(for version: String) {
        if expandedVersions.contains(version) {
            expandedVersions.remove(version)
        } else {
            expandedVersions.insert(version)
        }
    }
}

// MARK: - Version Card

struct VersionCard: View {
    let version: ChangelogVersion
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Version header (always visible)
            Button(action: onTap) {
                HStack(spacing: CloveSpacing.medium) {
                    // Version badge
                    VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
                        Text("Version \(version.version)")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(CloveColors.primaryText)

                        Text(version.date)
                            .font(CloveFonts.small())
                            .foregroundStyle(CloveColors.secondaryText)
                    }

                    Spacer()

                    // Expand/collapse indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.shared.accent)
                }
                .padding(CloveSpacing.large)
            }
            .buttonStyle(PlainButtonStyle())

            // Changes list (collapsible)
            if isExpanded {
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    ForEach(version.changes) { change in
                        ChangeItemRow(item: change)
                    }
                }
                .padding(.horizontal, CloveSpacing.large)
                .padding(.bottom, CloveSpacing.large)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Change Item Row

struct ChangeItemRow: View {
    let item: ChangelogItem

    var body: some View {
        HStack(alignment: .top, spacing: CloveSpacing.small) {
            // Type indicator
            Image(systemName: item.type.icon)
                .font(.system(size: 14))
                .foregroundStyle(item.type.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: CloveSpacing.xsmall) {
                Text(item.type.label)
                    .font(CloveFonts.small())
                    .foregroundStyle(item.type.color)
                    .fontWeight(.semibold)

                Text(item.description)
                    .font(CloveFonts.body())
                    .foregroundStyle(CloveColors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, CloveSpacing.xsmall)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ChangelogView()
    }
}
