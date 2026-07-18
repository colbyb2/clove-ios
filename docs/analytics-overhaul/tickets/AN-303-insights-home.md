# AN-303 — Redesigned Insights home

- Status: done
- Phase: 4 — Insights and dashboard
- Dependencies: AN-301, AN-302

## Objective

Redesign the Insights landing screen around changes, recurring patterns, related factors, and data quality.

## Scope

- Current snapshot, comparable-period changes, evidence-backed discoveries, tracking coverage, recent/saved analyses, and clear empty states.
- Remove hard-coded correlation previews and misleading “AI-powered” labeling.

## Acceptance criteria

- Every displayed result comes from current user data or is clearly educational.
- Cards link to supporting metric or comparison details.
- Low coverage is visible before strong conclusions.
- Sections degrade gracefully when features are disabled.

## Verification

- UI tests for no-data, sparse, rich, and partially enabled states.
- Accessibility review and Clove scheme build.

## Completion notes

Replaced the Insights landing screen with a compact two-column dashboard for metrics, wellbeing, period changes, recurring patterns, tracking coverage, and comparisons. Each tile shows one live status and navigates to a focused detail screen where evidence and explanations live. Results load from the unified repository and include explicit loading, failure, sparse, and empty states. Removed misleading AI and placeholder-correlation copy. Verified by state review, accessibility-oriented labels/disclosures, analytics tests, and Clove device build on 2026-07-18.
