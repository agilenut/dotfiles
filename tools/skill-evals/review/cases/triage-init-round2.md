# Review skill case

## Facts

- Repo `acme-widgets`, branch `feat/42-widget-export`. Round 1, local
  mode, ended with fixes that changed behavior, so Step 14 started
  **round 2**. Round 2's Step 2 timestamp: `2026-11-25-104500`.
- Round 1's triage file is
  `.reviews/code/2026-11-25-101500-feat-42-widget-export-triage.md`. Its
  frontmatter now reads:

  ```yaml
  ---
  branch: feat/42-widget-export
  mode: local # round 1's, in every round
  reviewers-ran: [base, language]
  plan-file: .plans/widget-export.md
  timestamp: 2026-11-25T10:15:00
  start-status: |
    M src/export/csv.ts
  round: 1
  rerun-of: null
  reviewed-tree: 4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d
  suggestions-of: null
  outcome: next-round
  ---
  ```

- Round 2 runs the same reviewers, base and language.

## Question

You are at round 2's Step 8. Give round 2's triage file frontmatter
exactly as you write it now, from the opening `---` to the closing `---`.

```json
{
  "frontmatter": "<the frontmatter text, as a JSON string>"
}
```
