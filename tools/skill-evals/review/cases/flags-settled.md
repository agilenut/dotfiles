# Review skill case

## Facts

- Repo `acme-widgets`, branch `feat/42-widget-export`, local mode.
  **Round 2.** Round 2's triage file has
  `rerun-of: .reviews/code/2026-11-25-101500-feat-42-widget-export-triage.md`.
- No plan file, no review-preferences files.
- Round 1's triage file has this entry:
  - `#3 - [Suggestion] src/export/csv.ts:30 (base)`: "rename the
    misspelled variable `exprtRows` to `exportRows`". Status:
    `skipped (user redirected: "the name matches the other export modules; rename them all in a separate change")`.
- Reviewers `base-reviewer` and `language-reviewer` both wrote valid
  output. Step 6 wrote these lines for this round's only finding.

### R1 - [Suggestion] src/export/csv.ts:30 (base)

- Claim: the local variable `exprtRows` is a misspelling; rename it to
  `exportRows` for consistency.
- Code reality: line 30 declares `const exprtRows = filterRows(rows);`,
  used on lines 31 and 33.
- Verified: yes - the name is a misspelling of `exportRows`.

A grep for the literal token `exprtRows`, outside the lines under review,
finds it in three other places:

```text
src/export/pdf.ts:12:  const exprtRows = filterRows(rows);
src/api/routes.ts:40:  res.json({ count: exprtRows.length });
src/jobs/nightly.ts:8:  let exprtRows = [];
```

## Question

Finish Step 7 for R1, second-pass flags included. Give its final bucket,
its pattern-wide flag, and the reason you write in its triage entry.

```json
{
  "id": "R1",
  "bucket": "auto-fix | auto-skip | needs-review | logged-polish",
  "pattern_wide": "<true | false>",
  "reason": "<the triage reason>"
}
```
