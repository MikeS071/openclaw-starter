# Template — Systematic Debugging

Use this when debugging anything non-trivial (recurring bug, flaky behavior, performance regression, proxy/HMR issues).

## Phase 1 — Reproduce + Baseline
- **Symptom:**
- **Where observed:** (URL, env, device)
- **Repro steps:**
- **Expected vs actual:**
- **Baseline checks:**
  - logs captured (paths + relevant lines)
  - version/commit
  - confirm it happens twice (not a one-off)

## Phase 2 — Instrument + Observe
- Add minimal instrumentation (logs/metrics) at the *narrowest* boundary.
- Record:
  - timestamps
  - request ids / correlation ids
  - inputs / outputs

## Phase 3 — Hypothesis → Minimal Fix
- **Top 1 hypothesis:**
- **Proof needed to confirm/deny:**
- **Minimal change:** (smallest diff that could fix it)
- Apply change.

## Phase 4 — Verify + Regress
- **Verification commands:**
- **Screenshots / outputs:**
- **Negative test:** (what should not happen)
- **Regression sweep:** (related flows)

## Completion note
Write a 3-bullet summary:
1) root cause
2) fix
3) proof
