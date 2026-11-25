# Review skill case

## Facts

- Repo `acme-widgets`, branch `feat/42-widget-export`. Round 1, local
  mode. The work is issue #42 (widget export), commit 2 of 3 in the plan.
- Step 10 applied two auto-fixes. Step 7 auto-skipped one finding. There
  are no foundational items. There are three needs-review items, so Step 9
  printed nothing.
- The first question is item #4:
  - [Suggestion] `src/export/csv.ts:30` (base)
  - Claim: rename the misspelled variable `exprtRows` to `exportRows`.
  - Verified: yes - `exprtRows` is a misspelling.
  - Pattern-wide: true; the same token appears in 3 other places outside
    this diff (`src/export/pdf.ts:12`, `src/api/routes.ts:40`,
    `src/jobs/nightly.ts:8`).
  - Your recommendation: SKIP. Renaming it in three files outside this
    change is a separate cleanup; inside this diff the name is consistent
    with those files.

## Question

You are at Step 11 and about to ask the first Step 12 question. Give the
chat text you print, exactly, from the first line to the status line.

```json
{
  "printed": "<the exact chat text, as a JSON string>"
}
```
