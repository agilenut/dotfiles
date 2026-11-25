# Review skill case

## Facts

- Repo `acme-widgets`, branch `feat/42-widget-export`. **Round 1, local
  mode.**
- Triage file:
  `.reviews/code/2026-11-25-101500-feat-42-widget-export-triage.md`.
- Reviewers `base-reviewer` and `language-reviewer` both wrote valid
  output. The review covered the whole diff.
- Steps 7-12: one auto-fix. `src/export/csv.ts:52` had
  `for (let i = 0; i <= rows.length; i++)`, which read past the end of
  `rows` and threw on every export; the fix changed it to `i < rows.length`.
  The build passed. No needs-review or foundational items.
- Now at Step 14. Pre-commit passes with no changes.

## Question

Work through Step 14 item 1, and the parts of items 2 and 4 that apply.

```json
{
  "next_round_due": "<true | false>",
  "starts_round": "<the round number you start next, or null>",
  "asks_user_before_next_round": "<true | false>",
  "mark_command": "<the exact review-gate command you run, or null>",
  "outcome": "recorded | next-round | not-recorded | paused",
  "record_line": "<the record line, exactly as printed>",
  "next_triage_round_field": "<the round: value of the next round's triage file, or null>",
  "next_triage_rerun_of": "<the rerun-of: value of the next round's triage file, or null>"
}
```
