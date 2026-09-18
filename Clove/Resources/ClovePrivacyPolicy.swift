import Foundation

/// The canonical privacy copy shown inside Clove. Keep PRIVACY.md and the App Store
/// disclosure checklist aligned with this implementation-facing source of truth.
enum ClovePrivacyPolicy {
    static let effectiveDate = "September 18, 2026"
    static let contactURL = URL(string: "https://github.com/colbyb2/clove-ios/issues")!

    static let text = """
    Effective Date: \(effectiveDate)

    Summary
    Clove is a free, open-source health tracker designed to work without an account or Clove-operated server. Health records and preferences you enter are stored locally on your device. Clove does not send them to the developer, analytics providers, advertisers, or data brokers.

    Data Stored on Your Device
    Clove stores the information you choose to enter, such as symptoms, mood, pain, energy, medications, meals, activities, notes, cycle information, and app preferences. This information is used on your device to provide tracking, history, charts, and insights.

    Local Diagnostics
    Clove can store aggregate reliability, interaction, and performance counters locally on your device. These counters do not include health values, notes, dates, metric names, or personal identifiers. They are not transmitted. You can disable Local Diagnostics in Settings, which also clears the stored counters.

    Permissions
    Clove may request notification permission for reminders you configure. Notifications are scheduled locally. Clove does not request access to contacts, photos, HealthKit, or your location.

    Exports and Backups
    CSV exports and Clove backup files are created only when you request them. You choose where to share or save each file. After a file leaves Clove, its privacy depends on the destination and anyone you share it with. Clove does not automatically upload or synchronize these files. Backups created by iOS, Finder, or device-management software are controlled by those systems, not by Clove.

    Security
    Clove stores its database inside the app's iOS sandbox and relies on the protections provided by your device and iOS. Clove does not add database-level encryption to its SQLite database. Protect your device with a passcode or biometric lock and treat exported files as sensitive health information.

    Third-Party Code and Services
    Clove uses the open-source GRDB library to access its local SQLite database. GRDB runs within the app and does not receive your data. Clove contains no advertising SDK, remote analytics SDK, or developer-operated cloud sync.

    Deleting Your Data
    Clove has no account to delete and holds no server copy of your records. Deleting Clove removes its local app data from that device. Files you exported and copies retained in device or computer backups must be deleted from those locations separately.

    Children
    Clove is not intended for use by children under 18 without the involvement of a parent or guardian.

    Changes and Contact
    This policy will be updated when Clove's data practices materially change. Questions or concerns can be submitted through the public project issue tracker:
    \(contactURL.absoluteString)
    """

    static let popup = Popup(
        id: "privacyPolicy",
        type: .terms,
        title: "Privacy Policy",
        message: text
    )
}
