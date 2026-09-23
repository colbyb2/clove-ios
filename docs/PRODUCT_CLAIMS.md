# Product Claims and Verification

This register is the source of truth for public claims about Clove. The owner for every claim is the **Clove maintainer**. Re-check affected claims whenever their evidence changes and before publishing a release that changes data handling, analytics, backup, accessibility, or licensing.

Last verified: **September 22, 2026**

| Public claim | Verification | Important limit |
| --- | --- | --- |
| Clove works without an account or Clove-operated server. | [App entry point](../Clove/App/CloveApp.swift), [privacy policy source](../Clove/Resources/ClovePrivacyPolicy.swift) | Apple-controlled distribution, device backup, and notification services are outside Clove's control. |
| Health records are stored locally in SQLite. | [Database manager](../Clove/Persistence/DatabaseManager.swift), [GRDB dependency](../Clove.xcodeproj/project.pbxproj) | The database is inside the app sandbox; Clove does not add database-level encryption. |
| Clove has no advertising SDK, remote analytics SDK, or developer-operated cloud sync. | [Package dependencies](../Clove.xcodeproj/project.pbxproj), [local diagnostics recorder](../Clove/Services/AnalyticsDiagnosticsRecorder.swift) | Re-verify whenever dependencies or network features change. Local diagnostics remain on the device. |
| Clove can track daily health and context data. | [Daily log model](../Clove/Models/DailyLog.swift), [Today view](../Clove/Views/Today/TodayView.swift), [tracking settings](../Clove/Models/UserSettings.swift) | Only enabled modules appear, and users choose what to record. |
| Clove provides charts, summaries, trends, and relationship analysis. | [Metric analysis](../Clove/Metrics/Analysis/MetricAnalysisSummary.swift), [relationship engine](../Clove/Metrics/Analysis/RelationshipEngine.swift), [insights engine](../Clove/Services/InsightsEngine.swift) | Results are deterministic statistics, not AI, diagnosis, causation, or future-health prediction. Missing data can materially affect results. |
| Cycle tracking can estimate the next period from prior marked starts. | [Cycle manager](../Clove/Services/CycleManager.swift), [cycle overview](../Clove/Views/Settings/CycleOverviewView.swift) | The estimate needs enough plausible history, can be wrong, and is not medical advice. |
| Clove exports CSV. | [CSV export](../Clove/Services/DataManager.swift) | CSV is a portable subset and is not a lossless full backup. |
| Clove creates and restores versioned JSON backups. | [Archive format and restore](../Clove/Services/DataImport/CloveArchiveManager.swift), [import interface](../Clove/Services/DataImport/DataImportSheet.swift) | Users remain responsible for retaining backup files. Compatibility is governed by the archive version. |
| Clove creates a verified recovery backup before replacement imports and restores. | [Recovery checkpoint implementation](../Clove/Services/DataImport/DataImportManager.swift), [archive validation](../Clove/Services/DataImport/CloveArchiveManager.swift) | This protects the replacement operation; it is not cloud backup or a guarantee against device loss. |
| Clove schedules user-configured reminders locally. | [Notification manager](../Clove/Services/NotificationManager.swift), [reminder interface](../Clove/Views/Settings/NotificationsView.swift) | Delivery is controlled by iOS notification permission and system scheduling. |
| Clove includes accessibility support for many primary controls. | [Accessible input components](../Clove/Views/Shared/AccessibleInputComponents.swift), [date navigation accessibility](../Clove/Views/Shared/DateNavigationHeader.swift) | Coverage is incomplete and has not been certified against WCAG or another conformance standard. |
| Clove is open-source software under the MIT License. | [LICENSE](../LICENSE), [OSI license listing](https://opensource.org/licenses) | MIT permits commercial reuse and does not require modified versions to publish their source. The copyright and permission notices must be retained. |

## Claims Clove does not make

- Clove does not provide medical advice, diagnosis, treatment, or emergency monitoring.
- Clove does not claim that a displayed relationship proves causation.
- Clove does not use AI to generate insights or predict future health outcomes. Its cycle estimate is a date calculation from prior marked starts, not a health-outcome prediction.
- Clove does not claim complete accessibility conformance.
- Clove does not claim custom database encryption or end-to-end encryption.
- A CSV export is not described as a complete backup.

## Update checklist

Before changing a public claim:

1. Identify the code or test that verifies it.
2. State its user-visible limitation next to the claim.
3. Update the README, privacy policy, in-app copy, and App Store disclosures as applicable.
4. Update the verification date and evidence link in this register.
