# Review skill case

## Facts

- Repo `acme-widgets`, branch `feat/42-widget-export`. Round 1, local
  mode. No plan file, no review-preferences files, no prior triage.
- Reviewers `base-reviewer` and `language-reviewer` both wrote valid
  output. Step 6 wrote these lines for the only finding.

### W1 - [Suggestion] src/export/csv.ts:30 (base)

- Claim: the local variable `exprtRows` is a misspelling; rename it to
  `exportRows` for consistency with the rest of the module.
- Code reality: line 30, added by this diff, declares
  `const exprtRows = filterRows(rows);`, used on lines 31 and 33.
- Verified: yes - the name is a misspelling of `exportRows`.

The second-pass grep for the literal token `exprtRows`, excluding the
lines under review and the excluded folders, found it in three other
places, outside this diff:

```text
src/export/pdf.ts:12:  const exprtRows = filterRows(rows);
src/api/routes.ts:40:  res.json({ count: exprtRows.length });
src/jobs/nightly.ts:8:  let exprtRows = [];
```

## Question

Finish Step 7 for W1, second-pass flags included. Give its final bucket
and flags.

```json
{
  "id": "W1",
  "bucket": "auto-fix | auto-skip | needs-review | logged-polish",
  "pattern_wide": "<true | false>",
  "other_occurrences": "<number>"
}
```
