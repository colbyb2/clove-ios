# AN-002 — Current metric catalog and policies

- Status: done
- Phase: 1 — Trustworthy foundation
- Dependencies: AN-001

## Objective

Create the authoritative catalog of semantics for every current static and dynamic metric family.

## User outcome

Hydration, bowel movements, symptoms, medication, meals, activities, cycle data, weather, and core ratings receive meaningful summaries and charts.

## Scope

- Catalog source, unit, domain, directionality, daily reducer, period reducer, missing policy, minimum samples, and supported analyses.
- Split bowel movement frequency from Bristol type.
- Define hydration average-versus-total behavior.
- Treat weather as categorical.
- Define scheduled versus as-needed medication semantics.
- Define event and explicit-none limitations for meals and activities.
- Update `DATA_SEMANTICS.md` with the completed matrix.

## Non-goals

- Add new tracking fields solely to resolve unavailable explicit-none states.
- Build charts or insights.

## Acceptance criteria

- Every provider registered by `MetricRegistry` maps to a catalog definition.
- Dynamic metric families have deterministic rules.
- Unsupported analyses are explicitly disabled.
- Ambiguous source data is documented as a limitation rather than silently imputed.
- Product terminology and database meaning agree.

## Verification

- Catalog completeness test against registered definitions.
- Review fixture covering each metric family.
- Clove scheme build.

## Completion notes

Completed 2026-07-18.

- Added `MetricCatalog` as the executable source of truth for 12 static/derived definitions and four dynamic metric families.
- Cataloged source provenance, measurement level, unit, domain, directionality, daily/weekly/monthly reducers, missing policy, supported analyses, minimum samples, visualizations, and display formatting.
- Corrected hydration to continuous daily fluid volume with average daily long-range summaries; weather to categorical distributions; and core 0–10 ratings to ordinal values with metric-specific favorability.
- Separated Bristol Stool Type from derived Bowel Movement Frequency while retaining the current provider ID until `AN-006` owns identity migration.
- Defined medication adherence as an eligible-dose-weighted percentage that excludes as-needed medication. Individual medication, activity, and food metrics use positive-event semantics and never infer an explicit negative from no entry.
- Added exhaustive provider-to-catalog mapping and debug completeness assertions for all static and data-generated providers.
- Added pure catalog checks covering validity, unique IDs, corrected semantics, source provenance, dynamic families, and unsupported analysis policies.
- Expanded `DATA_SEMANTICS.md` with the complete review matrix, sample floors, and known source limitations.
- Verification passed: standalone semantics/catalog executable, `git diff --check`, and generic iOS Clove build with code signing disabled.
