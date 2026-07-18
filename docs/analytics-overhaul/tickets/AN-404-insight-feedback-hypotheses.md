# AN-404 — Insight feedback and hypotheses

- Status: done
- Phase: 5 — Advanced discovery
- Dependencies: AN-303, AN-401

## Objective

Let users save, dismiss, rate, and intentionally revisit discoveries or personal hypotheses.

## Scope

- Useful/not useful feedback, dismissal duration, save state, hypothesis configuration, recalculation schedule, and local persistence.

## Acceptance criteria

- Dismissed insights do not immediately reappear unchanged.
- Feedback never changes underlying statistical evidence.
- Hypotheses clearly distinguish planned observation from proof.
- All health content and feedback remain local unless a later explicit privacy decision changes that.

## Verification

- Persistence, deduplication, recurrence, and deletion tests.
- Clove scheme build.

## Completion notes

Added local GRDB persistence for useful/not-useful ratings, bookmarks, 30-day dismissals, and user-created metric hypotheses with review intervals. Feedback is presentation metadata and never enters the evidence pipeline. Persistence, expiry, review, and deletion tests pass, and hypotheses are explicitly labeled as tracking plans rather than proof.
