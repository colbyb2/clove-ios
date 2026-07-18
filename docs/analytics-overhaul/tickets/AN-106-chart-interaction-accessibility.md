# AN-106 — Chart interaction and accessibility

- Status: done
- Phase: 2 — Unified charts and metric details
- Dependencies: AN-103, AN-104

## Objective

Make charts explorable and understandable without relying on sight, precision tapping, or full-screen navigation.

## Scope

- Scrubbing, selection annotations, event markers, goal/reference bands, zoom or range controls, and full-screen behavior.
- VoiceOver chart descriptors, textual summaries, Dynamic Type, contrast, and Reduce Motion support.

## Acceptance criteria

- A tap does not unexpectedly force full screen.
- Selected values include date, unit, and aggregation context.
- Every chart has an equivalent accessible summary.
- Controls meet target size and contrast requirements.

## Verification

- Manual accessibility checklist and automated UI coverage where practical.
- Clove scheme build.

## Completion notes

- Added chart scrubbing with date, formatted unit, and aggregation context; event markers and the hydration goal reference are first-class chart marks.
- Removed the metric-card tap that unexpectedly forced a full-screen chart. Range chips and the custom range sheet provide intentional zoom/range controls.
- Each chart is exposed to VoiceOver as one descriptive element with an equivalent textual value and evidence count. Selected values and notable-date controls have explicit labels or hints.
- Interactive controls use at least 44-point targets, summary cards adapt vertically at large text sizes, charts use theme contrast, and new motion respects Reduce Motion.
- Manual review checklist: standard and accessibility text sizes, VoiceOver chart summary and controls, Reduce Motion range changes, light/dark theme contrast, and one-handed scrub behavior.
