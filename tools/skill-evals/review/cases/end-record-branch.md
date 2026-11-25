# Review skill case

## Facts

- Repo `acme-widgets` (has a `.pre-commit-config.yaml`), branch
  `feat/42-widget-export`. **Round 1, branch mode** (`/pr` ran
  `/review branch` before the branch's first push). Four commits since
  `<base>`.
- Step 1's starting state (`git status --short`) was empty.
- Triage file:
  `.reviews/code/2026-11-25-101500-feat-42-widget-export-triage.md`.
- Reviewers `base-reviewer` and `language-reviewer` both wrote valid
  output over the whole `<base>..HEAD` diff and the per-commit patches.
- Steps 7-12: one auto-fix, a typo in `README.md` ("exprot" → "export").
  No questions.
- Now at Step 14. Pre-commit passes with no changes.
- If you run `review-gate mark`, assume it succeeds and prints
  `Recorded branch review of tree 9f8e7d6c5b4a`.

## Question

Work through Step 14 items 1, 2, and 4.

```json
{
  "next_round_due": "<true | false>",
  "staged_paths": ["<each path you stage in item 2>"],
  "mark_command": "<the exact review-gate command you run, or null>",
  "outcome": "recorded | next-round | not-recorded | paused",
  "record_line": "<the first line of the record line, exactly as printed>"
}
```
