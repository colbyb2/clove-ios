# Analytics Privacy and Diagnostics

All health analysis runs on-device. Clove has no analytics transmission client, remote event endpoint, advertising identifier, or third-party telemetry SDK.

## Local diagnostics

Users may disable Local Diagnostics in Settings. When enabled, Clove stores aggregate counters in `UserDefaults` for:

- generic area: Insights home, metric detail, Discover, Compare, or migration;
- generic outcome: success, failure, or cancellation;
- coarse duration bucket;
- generic interaction type such as range change, bookmark, dismissal, or hypothesis review;
- count.

There is no free-form payload field and no event timestamp. Opting out immediately clears the counters. Product behavior is identical when diagnostics are absent.

## Prohibited data

Diagnostic payloads may never contain metric names or IDs, measurements, notes, dates, insight titles/text, medication or food names, symptoms, source-record identifiers, user identifiers, or database error descriptions. Tests enforce the allowed schema.

## Transmission gate

No transmission is enabled. Enabling one later requires a new accepted decision, explicit data inventory, privacy-policy review, consent behavior, retention/deletion policy, schema tests, and manual network inspection. Local aggregate counters must not be treated as authorization to transmit.
