# Template — Review Rubric (Agent + Human)

## 1) Scope compliance
- Does the change match the approved spec/PRD?
- Any extra features or refactors sneaking in?

## 2) Correctness
- Edge cases handled?
- Error handling explicit?
- Idempotency where needed?

## 3) Security
- Auth/tenant isolation correct?
- No hardcoded secrets?
- Input validation at boundaries?

## 4) Performance
- Any new polling loops?
- Avoid unnecessary DB scans?

## 5) Verification evidence
- Tests run? build clean?
- For UI: screenshot/proof steps

## Verdict
- **Approve** / **Warn** / **Block**
- If Warn/Block: list issues by severity (`critical > high > medium > low`)
