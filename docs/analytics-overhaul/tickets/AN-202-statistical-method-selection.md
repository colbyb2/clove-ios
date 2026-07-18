# AN-202 — Statistical method selection

- Status: done
- Phase: 3 — Relationship engine
- Dependencies: AN-201

## Objective

Select and calculate relationship methods appropriate to each pair of measurement levels.

## Scope

- Pearson, Spearman, point-biserial, phi, Cramér's V, and supported grouped effect sizes.
- Explicit unsupported combinations and method metadata.

## Acceptance criteria

- Pearson is not the universal fallback.
- Ordinal, binary, and categorical pairs use appropriate methods.
- Constant and degenerate samples return limitations, not fabricated zero relationships.
- Results match trusted reference values within documented tolerance.

## Verification

- Reference fixtures for every supported method.
- Clove scheme build.

## Completion notes

Implemented semantic selection and calculation for Pearson, Spearman, point-biserial, phi, Cramér’s V, and correlation ratio. Constant and unsupported samples return structured limitations.
