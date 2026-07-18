# Analytics Ticket Index

Ticket order and phase gates are maintained in [../ROADMAP.md](../ROADMAP.md).

## Ticket fields

Every ticket contains status, phase, dependencies, objective, user outcome, scope, non-goals, acceptance criteria, verification, and completion notes.

## Execution rules

1. Confirm all dependencies are `done`.
2. Change the ticket to `in-progress` before editing product code.
3. Keep implementation within scope; document necessary changes first.
4. Run the ticket's verification plus `git diff --check`.
5. Update related architecture, semantics, and decisions.
6. Fill in completion notes and mark the ticket `done`.
7. Update the roadmap before selecting the next ticket.

## Definition of done

- Acceptance criteria pass.
- Relevant automated tests exist and pass.
- The Clove scheme builds successfully.
- Empty, sparse, missing, and normal-data states were considered.
- Accessibility is checked for user-facing changes.
- No new unsupported medical or causal claims are introduced.
- Documentation matches shipped behavior.

