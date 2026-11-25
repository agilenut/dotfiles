# Review skill case

## Facts

- Repo `acme-widgets` (has a `.pre-commit-config.yaml`), branch
  `feat/42-widget-export`. **Round 1, local mode.**
- Step 1's starting state (`git status --short`):

  ```text
   M src/export/csv.ts
  ?? src/export/csv.test.ts
  ```

- Step 2 took both paths as the change and staged them. Triage file:
  `.reviews/code/2026-11-25-101500-feat-42-widget-export-triage.md`.
  Commit message draft:
  `.reviews/code/2026-11-25-101500-feat-42-widget-export-commit-msg.txt`.
- Reviewers `base-reviewer` and `language-reviewer` both wrote valid
  output; none failed or was salvaged. The review covered the whole diff.
- Steps 7-12: two auto-fixes, both typos in comments in
  `src/export/csv.ts` ("recieve" → "receive", "teh" → "the"). The build
  passed after each. No needs-review or foundational items, so there was
  no dialog.
- Now at Step 14. `pre-commit run` passes with no changes.
  `git diff --cached --name-only` prints `src/export/csv.test.ts` and
  `src/export/csv.ts`.
- If you run `review-gate mark`, assume it succeeds and prints
  `Recorded commit review of tree 1a2b3c4d5e6f`.

## Question

Work through Step 14 items 1, 2, and 4.

```json
{
  "next_round_due": "<true | false>",
  "starts_round": "<the round number you start next, or null>",
  "mark_command": "<the exact review-gate command you run, or null>",
  "outcome": "recorded | next-round | not-recorded | paused",
  "outcome_reason": "<or null>",
  "record_line": "<the first line of the record line, exactly as printed>"
}
```
