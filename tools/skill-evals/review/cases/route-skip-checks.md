# Review skill case

## Facts

- Repo `acme-widgets`, branch `feat/42-widget-export`. Round 1, local mode.
- No plan file. Reviewers `base-reviewer` and `language-reviewer` both
  wrote valid output.
- `<project-root>/.claude/review-preferences.md` holds one rule:
  `Don't flag missing JSDoc on exported functions; this codebase documents its API in docs/api.md.`
- Step 2's prior-triage scan found
  `.reviews/code/2026-11-20-143000-feat-42-widget-export-triage.md`
  (`branch: feat/42-widget-export`, `rerun-of: null`). It has these two
  entries:
  - `#3 - [Suggestion] src/export/csv.ts:12 (base)`: "exportCsv should
    stream rows instead of building the whole string in memory." Status:
    `skipped (user accepted SKIP)`. The user's reason: exports are capped
    at 5,000 rows.
  - `#5 - [Suggestion] docs/export.md:30 (language)`: "'exprot' is a typo
    for 'export'." Status: `auto-skipped`, reasoning: "docs/export.md was
    not in that diff."
- Step 6 wrote these lines for this run's findings.

### P1 - [Suggestion] src/export/csv.ts:5 (base)

- Claim: the exported function `exportCsv` has no JSDoc comment.
- Code reality: line 5 declares `export function exportCsv(rows)` with no
  comment above it.
- Verified: yes - no JSDoc on the exported function.

### P2 - [Suggestion] src/export/csv.ts:14 (base)

- Claim: `exportCsv` builds the whole CSV string in memory; it should
  stream rows to the response.
- Code reality: lines 14-20 join all rows into one string before writing.
- Verified: yes - the function buffers the whole output.

### P3 - [Suggestion] docs/export.md:30 (language)

- Claim: "exprot" on line 30 is a typo for "export".
- Code reality: this diff edits docs/export.md, including line 30, which
  reads "Run the exprot job from the admin page."
- Verified: yes - the typo is on a line this diff changed.

## Question

Apply Step 7 to P1-P3. Give each finding's bucket and the reason you
would write in its triage entry.

```json
{
  "findings": [
    {
      "id": "P1",
      "bucket": "auto-fix | auto-skip | needs-review | logged-polish",
      "reason": "<the triage reason>"
    }
  ]
}
```
