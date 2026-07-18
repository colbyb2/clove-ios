# AN-503 — Privacy-safe product telemetry

- Status: done
- Phase: 6 — Validation and rollout
- Dependencies: AN-303, AN-502

## Objective

Measure feature usability and reliability without transmitting private health measurements or analysis contents.

## Scope

- Document allowed event taxonomy, prohibited fields, aggregation, consent/settings behavior, and local diagnostics.
- Track screen use, load success/failure, generic interaction types, and performance buckets only if an approved telemetry mechanism exists.

## Acceptance criteria

- Metric names, values, notes, dates, insight text, medication names, foods, symptoms, and identifiers are prohibited payloads.
- Analytics calculations remain on-device.
- Telemetry absence does not affect product functionality.
- Privacy review and data inventory are documented before any transmission is enabled.

## Verification

- Payload-schema tests and manual network inspection if telemetry is enabled.
- Clove scheme build.

## Completion notes

No approved transmission mechanism exists, so Phase 6 enables no network telemetry. Added optional local aggregate diagnostics with a closed typed schema, coarse performance buckets, immediate opt-out deletion, and prohibited-field tests. The complete data inventory and future transmission gate are documented in `docs/analytics-overhaul/PRIVACY.md`.
