# Analytics Overhaul

This directory is the source of truth for Clove's analytics overhaul. The work is divided into six phases and implemented one bounded ticket at a time.

## Working agreement

- Only one ticket may be `in-progress` at a time.
- A ticket is complete only when every acceptance criterion and required check passes.
- Each ticket must leave the app buildable and usable.
- New architecture is introduced behind adapters until its replacement is ready.
- Decisions that affect later tickets are recorded in `DECISIONS.md`.
- Scope changes are written into the affected ticket before implementation continues.
- Medical or causal claims must never be inferred from observational data.

## Documents

- [ROADMAP.md](ROADMAP.md): phases, dependency order, progress, and release gates.
- [ARCHITECTURE.md](ARCHITECTURE.md): current state and target analytics pipeline.
- [DATA_SEMANTICS.md](DATA_SEMANTICS.md): rules for units, missing data, aggregation, and interpretation.
- [DECISIONS.md](DECISIONS.md): durable architecture and product decisions.
- [TESTING.md](TESTING.md): analytics test commands, fixtures, and numeric conventions.
- [tickets/README.md](tickets/README.md): ticket index and status definitions.
- [METHODS.md](METHODS.md): production analysis-method reference.
- [PERFORMANCE.md](PERFORMANCE.md): budgets and profiling record.
- [PRIVACY.md](PRIVACY.md): local diagnostics inventory and privacy gate.
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md): operational diagnosis guide.

## Status values

- `backlog`: defined but not ready to start.
- `ready`: dependencies are complete and acceptance criteria are actionable.
- `in-progress`: the single ticket currently being implemented.
- `blocked`: cannot proceed until a documented dependency or decision is resolved.
- `done`: implementation, tests, documentation, and verification are complete.

## Current position

All six phases are complete, and the analytics overhaul is at general availability. No ticket is in progress.
