# Analytics Data Semantics

This document defines rules that all metric definitions and analysis services must follow. The executable source of truth is `Clove/Metrics/Core/MetricCatalog.swift`; the tables below summarize it for review.

## Observation states

- `observed(value)`: the user explicitly recorded a value.
- `explicitNone`: the user explicitly recorded that an event or condition did not occur.
- `missing`: no conclusion can be drawn for that metric on that day.
- `notApplicable`: the metric was not expected or eligible that day, such as an unscheduled medication.

Missing values must never silently become zero. Charts show gaps for missing continuous data. Rates disclose their eligible and observed denominators.

## Measurement levels

- `continuous`: numeric measurement where differences are meaningful.
- `ordinal`: ordered categories where distance is not guaranteed equal.
- `binary`: explicit yes/no observation.
- `categorical`: unordered categories.
- `count`: number of events in a defined interval.
- `event`: timestamped occurrence with optional attributes.
- `percentage`: bounded rate with a known denominator.

## Required metric metadata

Every metric definition must specify:

- Stable ID and source
- Measurement level and unit
- Valid domain
- Directionality: higher-better, lower-better, or neutral
- Daily, weekly, and monthly reducers
- Missing and explicit-zero policy
- Minimum sample sizes
- Supported analyses
- Display formatting and chart recommendations

## Identity and naming

- Metric IDs are stable data identities, not display strings.
- New static IDs use lowercase words separated by underscores, such as `pain_level`.
- New dynamic IDs are namespaced with a stable source-record ID, such as `symptom:42`; names must not be embedded as identity.
- Display names may be renamed or localized without changing metric IDs.
- Legacy IDs remain representable during migration even when they do not follow the new naming convention.
- A new metric must define its semantics before it is registered. It must not rely on generic chart defaults to decide meaning.
- Extensions may add presentation metadata, but must not override source, unit, aggregation, absence, or directionality rules outside the metric catalog.

## Aggregation principles

- Continuous and ordinal daily ratings normally use an average or median across periods; the chosen reducer must be explicit.
- Counts use sums when describing total events and rates/averages when comparing unequal periods.
- Binary values aggregate to an occurrence rate over eligible observed days.
- Percentages aggregate using their underlying numerator and denominator when available, not an unweighted mean of percentages.
- Categorical values aggregate to distributions; a mode may be shown but must not replace the distribution.
- Event attributes are not converted to counts unless the requested measure is event frequency.

## Canonical source rules

- Canonical identity combines metric identity with a persistence record and field reference. Editing a saved record does not change its observation or event identity.
- Unsaved records receive deterministic fixture identities and an `unstableSourceIdentity` quality flag; production repository loads are expected to have database IDs.
- Analytics days are normalized by an explicitly injected calendar and timezone. The timezone identifier is part of the day key so results cannot silently mix day definitions.
- Daily reducers sort by timestamp and stable identity before reducing, making results independent of repository return order.
- Event reducers preserve the original timestamped records and attributes alongside reduced daily observations.
- Unknown categories are preserved and flagged. Invalid numeric domain values are excluded from observed reductions and retained in raw source events where available.

## Interpretation principles

- Trend direction and health direction are separate. Rising pain is an increasing trend but an unfavorable change.
- Association never implies causation.
- Results disclose sample size, date range, coverage, method, and limitations.
- Automated discovery applies multiple-comparison correction.
- Automatic discovery requires coverage, minimum samples, an effect threshold, and a Benjamini–Hochberg adjusted q-value before ranking. A budget-limited run discloses its tested family.
- Cycle phase is unknown outside two explicit plausible cycle starts; the app does not infer an unrecorded start or extrapolate a future phase.
- Personal baseline labels compare the latest seven observations with robust personal history. “Above” and “below” do not imply medically better or worse.
- Sparse results use cautious language such as “early signal.”
- No recommendation should advise medication changes or replace professional medical care.

## Initial known corrections

- Hydration: daily ounces; long-range charts normally show average daily ounces, totals only when explicitly requested.
- Bowel movements: frequency and Bristol type are separate metrics.
- Weather: categorical unless a scientifically meaningful derived attribute is available.
- Symptoms: ordinal severity unless a symptom is explicitly binary.
- Medication adherence: scheduled doses taken divided by eligible scheduled doses; as-needed medication is analyzed separately.
- Meals and activities: lack of an entry is missing unless the user explicitly completed a daily tracker indicating none.

## Current metric catalog

Reducer notation is daily/weekly/monthly. Analysis notation is: descriptive (`D`), trend (`T`), distribution (`Dist`), frequency (`F`), period comparison (`PC`), relationship (`R`), lagged relationship (`L`), and event outcome (`EO`). An analysis not listed is intentionally unsupported.

| Metric | Source | Level and domain | Direction | Reducers | Unrecorded day | Analyses |
|---|---|---|---|---|---|---|
| Mood | `DailyLog.mood` | Ordinal score, 0–10 | Higher better | Latest/average/average | Missing | D, T, Dist, PC, R, L |
| Pain Level | `DailyLog.painLevel` | Ordinal score, 0–10 | Lower better | Latest/average/average | Missing | D, T, Dist, PC, R, L |
| Energy Level | `DailyLog.energyLevel` | Ordinal score, 0–10 | Higher better | Latest/average/average | Missing | D, T, Dist, PC, R, L |
| Hydration | `DailyLog.waterIntake` | Continuous fluid ounces, nonnegative | Neutral | Latest/average/average | Missing | D, T, Dist, PC, R, L |
| Flare Day | `DailyLog.isFlareDay` | Binary, 0/1 | Lower better | Latest/rate/rate | Missing | D, F, Dist, PC, R, L |
| Medication Adherence | `DailyLog.medicationAdherenceJSON` | Percentage, 0–100 | Higher better | Weighted percentage at every level | Missing | D, T, Dist, F, PC, R, L |
| Weather | `DailyLog.weather` | Categorical weather values | Neutral | Latest/distribution/distribution | Missing | D, Dist, PC, R, L |
| Activity Count | `ActivityEntry` | Count, nonnegative | Neutral | Sum/average/average | Missing | D, T, Dist, F, PC, R, L |
| Meal Count | `FoodEntry` | Count, nonnegative | Neutral | Sum/average/average | Missing | D, T, Dist, F, PC, R, L |
| Bristol Stool Type | `BowelMovement.type` | Ordinal Bristol type, 1–7 | Neutral | Distribution at every level | Missing | D, Dist, PC, R, L |
| Bowel Movement Frequency | `BowelMovement` events | Count, nonnegative | Neutral | Sum/average/average | Missing | D, T, Dist, F, PC, R, L |
| Flow Level | `Cycle.flow` | Ordinal flow level, 0–5 | Neutral | Latest/distribution/distribution | Missing | D, Dist, PC, R, L |
| Rated Symptom | `DailyLog.symptomRatingsJSON` | Ordinal score, 0–10 | Lower better | Latest/average/average | Missing | D, T, Dist, PC, R, L |
| Binary Symptom | `DailyLog.symptomRatingsJSON` | Binary, 0/1 after normalization | Lower better | Latest/rate/rate | Missing | D, F, Dist, PC, R, L |
| Medication Occurrence | `DailyLog.medicationsTaken` | Timestamp/day event | Neutral | Raw/count/count | Missing | D, F, Dist, PC, R, L, EO |
| Activity Occurrence | `ActivityEntry` | Timestamped event | Neutral | Raw/count/count | Missing | D, F, Dist, PC, R, L, EO |
| Meal/Food Occurrence | `FoodEntry` | Timestamped event | Neutral | Raw/count/count | Missing | D, F, Dist, PC, R, L, EO |

### Minimum samples

- Standard ordinal, continuous, count, categorical, and percentage metrics: 1 descriptive observation, 7 for trend, 14 matching observations for relationships, and 14 observations for repeated patterns.
- Binary and event families: 1 descriptive observation, 14 for trend or relationship analysis, and 28 for repeated patterns.
- These are catalog eligibility floors, not guarantees of strong evidence. Later inference tickets may require larger samples for a specific method.

### Source limitations

- A saved `DailyLog` with `isFlareDay == false` is an observed non-flare day; a day with no log is missing.
- A zero hydration value is currently persisted as no hydration value, so zero and unrecorded cannot yet be separated.
- Medication adherence includes only eligible scheduled medication in its numerator and denominator. As-needed medication is excluded. A log containing only as-needed records is not applicable; a log with no adherence records is missing and flagged as an ambiguous absence.
- `medicationsTaken` records occurrences but cannot prove that an absent medication was skipped, unscheduled, or simply untracked. Individual medication metrics therefore use event semantics and neutral directionality.
- Food and activity tables record positive events. No entry does not prove an explicit “none,” so individual events and daily counts remain missing outside observed records.
- Bowel events do not currently include an explicit daily “none.” Frequency and Bristol type are distinct definitions derived from the same event source.
- Binary symptom ratings are normalized from the stored rating representation into 0/1 using the existing UI threshold of 5 and are marked with a normalization quality flag.
- Weather remains categorical. Unknown or legacy strings must be preserved or classified as unknown; they must not be assigned an arbitrary numeric health order.
- Dynamic symptom, medication, meal, and activity metrics use durable canonical IDs. Name-derived IDs are compatibility aliases only; ambiguous legacy aliases never choose a canonical metric arbitrarily.
