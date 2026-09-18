# Clove App Store Privacy Disclosure Checklist

This checklist translates Clove's current implementation into App Store Connect privacy answers. Recheck it before every release and whenever networking, analytics, advertising, accounts, sync, permissions, or backup behavior changes.

## Current answers

- **Data used to track users:** None.
- **Data linked to the user:** None collected by Clove.
- **Data not linked to the user:** None transmitted or collected by Clove.
- **Advertising:** None.
- **Third-party analytics:** None.
- **Developer-operated cloud storage or sync:** None.
- **Accounts:** None.
- **Health and fitness data:** Entered and processed locally; not collected by the developer.
- **Diagnostics:** Aggregate reliability, interaction, and performance counters are optional, exclude health content and identifiers, remain on-device, and are cleared when disabled.
- **Notifications:** Used only for locally scheduled reminders after permission is granted.
- **User-initiated exports:** CSV and Clove backup files leave the app only through a destination selected by the user.

## Release verification

- Confirm the in-app Privacy Policy and `PRIVACY.md` still match current behavior.
- Confirm App Store Connect says the developer does not collect data unless a new feature actually transmits data off-device.
- Confirm screenshots, product-page copy, and release notes do not claim app-level or database-level encryption.
- Confirm the support destination is `https://github.com/colbyb2/clove-ios/issues`.
- Obtain appropriate legal review before publishing policy changes.
