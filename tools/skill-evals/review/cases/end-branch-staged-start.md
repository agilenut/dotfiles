# Review skill case

## Facts

- Repo `acme-widgets`, branch `feat/42-widget-export`. **Round 1, branch
  mode.** Three commits since `<base>`.
- Step 1's starting state (`git status --short`):

  ```text
  M  docs/notes.md
  ```

  `docs/notes.md` isn't changed by any of the branch's commits.

- Triage file:
  `.reviews/code/2026-11-25-101500-feat-42-widget-export-triage.md`.
- Reviewers `base-reviewer` and `language-reviewer` both wrote valid
  output over the `<base>..HEAD` diff and the per-commit patches.
- Steps 7-12: no fixes. All findings were auto-skipped.
- Now at Step 14.

## Question

Work through Step 14 items 1, 2, and 4.

```json
{
  "next_round_due": "<true | false>",
  "mark_command": "<the exact review-gate command you run, or null>",
  "outcome": "recorded | next-round | not-recorded | paused",
  "outcome_reason": "<or null>",
  "record_line": "<the record line, exactly as printed>"
}
```
