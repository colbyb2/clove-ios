# Analytics Decision Log

Record durable product and architecture decisions here. Each entry should include its date, status, context, decision, consequences, and affected tickets.

## AD-001 — Repository documentation is the source of truth

- Date: 2026-07-18
- Status: accepted
- Context: the overhaul spans many implementation sessions and six dependent phases.
- Decision: roadmap, ticket status, data semantics, and architectural decisions live under `docs/analytics-overhaul` and are updated with the implementation.
- Consequences: chat history is not treated as authoritative project state. Work starts by reading the roadmap and active ticket.
- Tickets: all

## AD-002 — Incremental migration through adapters

- Date: 2026-07-18
- Status: accepted
- Context: replacing both analytics stacks in one change would leave the app unstable for too long.
- Decision: introduce the target contracts first, adapt existing data sources, migrate consumers in vertical slices, then remove legacy services.
- Consequences: temporary adapters are expected and must be tracked for removal in `AN-305` or `AN-504`.
- Tickets: AN-003, AN-004, AN-102, AN-305

## AD-003 — Evidence before presentation

- Date: 2026-07-18
- Status: accepted
- Context: current UI strings can overstate confidence or imply causality.
- Decision: analysis services return structured evidence and limitations. Views produce user-facing language from those results.
- Consequences: hard-coded confidence values and causal recommendation strings are not permitted in the new pipeline.
- Tickets: AN-101, AN-203, AN-301

## AD-004 — Contract checks precede the XCTest harness

- Date: 2026-07-18
- Status: accepted
- Context: the Xcode project has no unit-test target; the existing files under `Clove/Metrics/Tests` are app-compiled debug views. Creating the real analytics test target is the explicit scope of `AN-007`, which depends on the contracts introduced by `AN-001`.
- Decision: `AN-001` ships deterministic, app-compiled contract checks for valid and invalid definitions. `AN-007` creates the XCTest target and migrates these cases without changing their expectations.
- Consequences: Phase 1 does not pretend the current demo views are unit tests, and test-target project changes remain contained in their dedicated ticket.
- Tickets: AN-001, AN-007

## AD-005 — Positive-event sources do not imply negative days

- Date: 2026-07-18
- Status: accepted
- Context: food, activity, individual medication, and bowel tables primarily record positive events. A missing event may mean none occurred, the user did not track it, or the event was not applicable.
- Decision: these families use event semantics with a missing unrecorded-day policy. Daily zeros or explicit-none observations may only be produced when a source record actually establishes them. Bristol stool type and bowel movement frequency are separate definitions, and weather remains categorical rather than receiving an arbitrary health order.
- Consequences: some current provider-generated zero values will not carry forward into canonical observations. Phase 2 charts and Phase 3 relationships will use honest coverage denominators instead of assuming untracked days are negative observations.
- Tickets: AN-002, AN-003, AN-101, AN-201

## AD-006 — Canonical observations preserve both reduction and provenance

- Date: 2026-07-18
- Status: accepted
- Context: charts need one deterministic value per day, while event-window analysis and auditability require the original records and timestamps.
- Decision: source adapters produce typed observations and raw events without querying the database. A separate pipeline applies catalog reducers using an injected calendar and timezone, returns explicit missing/none/not-applicable states, and carries stable source references and quality flags. Reduction never discards the raw-event collection.
- Consequences: `AN-004` can own date-bounded repository access without embedding persistence in the semantic layer. Later analysis can disclose quality and coverage, reconstruct event windows, and reproduce a daily result independent of database return order.
- Tickets: AN-003, AN-004, AN-101, AN-201, AN-205

## AD-007 — Analytics caches are revision-keyed

- Date: 2026-07-18
- Status: accepted
- Context: time-based caches and disconnected invalidation can display stale insights after an edit or auto-save.
- Decision: successful analytics-affecting writes increment one shared in-process revision. New cache keys include that revision plus exact metric IDs, range, granularity, policy version, and raw-event option. Presentation-only settings do not increment it.
- Consequences: analytics reads after a write cannot reuse stale new-pipeline results, concurrent identical loads can share work, and the revision remains session-local because calculated insights are not persisted.
- Tickets: AN-005, AN-102, AN-501

## AD-008 — Dynamic identity is durable and aliases may be ambiguous

- Date: 2026-07-18
- Status: accepted
- Context: name-derived metric IDs split history after renames and can collide for distinct names that normalize to the same slug.
- Decision: dynamic metric families use durable canonical IDs stored in the database. Old and renamed IDs are aliases; an alias that maps to multiple canonical IDs is treated as ambiguous instead of selecting one. Recreated symptom/medication records receive new identities, while retained meal/activity dimension identities may be reused by an exact normalized name.
- Consequences: renames and relaunches preserve analytic history, collisions remain distinct, inactive historical metrics remain queryable, and consumers must handle an unresolved ambiguous legacy ID explicitly.
- Tickets: AN-006, AN-207

## AD-009 — Analytics correctness is verified outside the app target

- Date: 2026-07-18
- Status: accepted
- Context: app-compiled debug checks cannot provide normal XCTest discovery, database isolation, or CI reporting.
- Decision: analytics contracts and statistical regressions live in `CloveAnalyticsTests`, using deterministic seeded fixtures and in-memory GRDB databases. Pure reference calculations use strict tolerances and iterative statistical methods document any wider tolerance they require.
- Consequences: later analysis tickets have a reusable correctness harness and must add known-positive, known-negative, sparse, and degenerate cases as applicable.
- Tickets: AN-007, AN-101 through AN-205, AN-501

## AD-010 — Chart presentation follows measurement semantics

- Date: 2026-07-18
- Status: accepted
- Context: one generic line chart and average/change summary misrepresent categorical, binary, event, count, and weighted-ratio data.
- Decision: chart and summary families are selected from `MetricDefinition`. Missing daily values split numeric lines, binary aggregation reports a rate and denominator, categorical and Bristol values use distributions, events use occurrence marks, and hydration includes an explicitly labeled goal reference. Presentation never recalculates the evidence model.
- Consequences: adding a metric requires meaningful semantic configuration and fixtures; unsupported modules are omitted rather than filled with generic statistics.
- Tickets: AN-101, AN-102, AN-103, AN-104

## AD-011 — Periods are half-open calendar-day ranges

- Date: 2026-07-18
- Status: accepted
- Context: elapsed-time subtraction creates unequal prior periods around DST and inclusive end labels can differ from repository boundaries.
- Decision: UI selections are converted to half-open intervals at calendar day boundaries. Previous periods contain the same number of calendar days and end exactly at the current start. All Time has no previous-period comparison.
- Consequences: custom and preset ranges share repository semantics, comparisons do not overlap, and coverage for both periods must be displayed.
- Tickets: AN-105, AN-201

## AD-012 — Relationship methods follow measurement semantics

- Date: 2026-07-18
- Status: accepted
- Context: the legacy comparison screen used Pearson, a three-day minimum, bucketed p-values, and coefficient magnitude as confidence for every metric pair.
- Decision: relationship alignment preserves missingness and selects methods from both measurement levels. Numeric, ordinal, binary, categorical, and event comparisons use distinct supported methods; uncertainty, coverage, limitations, and minimum samples are first-class result data. Lag scans are explicitly exploratory and every explanation uses association language.
- Consequences: unsupported or degenerate pairs show a limitation instead of a fabricated zero. Saved analyses persist configurations by canonical metric ID and always recalculate current evidence.
- Tickets: AN-201 through AN-207

## AD-013 — Wellbeing is a transparent snapshot, not a health score

- Date: 2026-07-18
- Status: accepted
- Context: the legacy dashboard reduced a few metrics to an opaque 0–100 Health Score, assigned hard-coded weights, and could make missing data look like poor health.
- Decision: the primary Insights experience presents mood, pain, energy, symptoms, and medication adherence as separate current/prior component summaries. Available components share equal visible weight for compatibility calculations; unavailable components receive zero weight and remain explicitly missing. Dynamic symptoms contribute once through a combined symptom component. No headline composite score appears on the Insights home.
- Consequences: users can inspect every value, comparison, coverage denominator, and weight. The snapshot states its limitations and that it is not medical advice. Any future personalized weighting requires a new product decision and must preserve component visibility.
- Tickets: AN-303, AN-304, AN-305

## AD-014 — Automatic discovery controls the tested family

- Date: 2026-07-18
- Status: accepted
- Context: scanning many metric pairs makes an apparently small p-value increasingly likely by chance and can make the Insights experience noisy.
- Decision: each automatic run has deterministic eligibility and a hard test budget, applies Benjamini–Hochberg correction across every estimable test in that run, requires both adjusted q-value and effect-size thresholds, and labels surviving results exploratory. Ranking may use precision, coverage, recency, and actionability only after those evidence gates pass.
- Consequences: the app may deliberately show no automatic finding. Budget-limited runs disclose the limit, stable IDs suppress duplicates, and future discovery families must define their corrected test family before release.
- Tickets: AN-401, AN-501

## AD-015 — Context, baselines, and feedback remain personal descriptive layers

- Date: 2026-07-18
- Status: accepted
- Context: cycle estimates, flare labels, historical baselines, and user feedback can become misleading if treated as diagnosis, universal norms, or statistical evidence.
- Decision: cycle phases exist only between explicit plausible cycle starts; flare comparisons use explicit daily-log states; baselines compare recent observations with robust personal history; and saved/dismissed/useful metadata changes presentation only. Hypotheses are tracking plans, not findings.
- Consequences: incomplete context produces an empty state rather than inference, gaps and definition changes qualify or invalidate baselines, no universal medical threshold is implied, and all feedback/hypothesis records remain local.
- Tickets: AN-402, AN-403, AN-404

## AD-016 — Rollback disables the surface, not correctness

- Date: 2026-07-18
- Status: accepted
- Context: the legacy analytics path was statistically inconsistent, so a rollout fallback must not silently restore it.
- Decision: the default-on local rollout flag may temporarily disable Insights and show a recoverable unavailable state. Database migration state is transactional, interruption-aware, and retryable. It never rewrites source health records merely to switch presentation.
- Consequences: fresh and upgraded installs share one calculation stack; failed migrations show a retry screen; and the flag may be removed after 2026-08-15 if no recovery defect needs it.
- Tickets: AN-502, AN-504

## AD-017 — Diagnostics are local aggregates until a new privacy decision

- Date: 2026-07-18
- Status: accepted
- Context: reliability and performance counters are useful, but health measurements and analysis content are highly sensitive and no transmission mechanism has been approved.
- Decision: diagnostics use a closed typed schema containing only generic area, outcome, interaction, coarse duration bucket, and count. They remain in `UserDefaults`, have no timestamps or identifiers, can be disabled and erased, and are never required for functionality. No network transmission is implemented.
- Consequences: free-form payload dictionaries and error descriptions are prohibited. Any future transmission requires a separate privacy review, consent and retention design, data inventory, tests, and network inspection.
- Tickets: AN-503, AN-504

## Decision template

```markdown
## AD-XXX — Title

- Date: YYYY-MM-DD
- Status: proposed | accepted | superseded
- Context:
- Decision:
- Consequences:
- Tickets:
```
