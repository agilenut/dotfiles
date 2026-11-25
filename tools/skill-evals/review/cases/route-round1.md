# Review skill case

## Facts

- Repo `acme-widgets`, branch `feat/42-widget-export`. Round 1, local mode.
- Plan file `.plans/widget-export.md` (status: active). Its endpoint table
  lists `GET /exports/:id/file` for downloading a finished export.
- No review-preferences files exist. No prior triage for this branch.
- Reviewers `base-reviewer` and `language-reviewer` both wrote valid
  output. Step 5 produced the four findings below, and Step 6 wrote these
  lines in the triage file.

### F1 - [Suggestion] src/export/csv.ts:88 (language)

- Claim: the error message the diff adds says "Unable to wirte file";
  "wirte" is a typo for "write".
- Code reality: line 88, added by this diff, is
  `throw new ExportError("Unable to wirte file");`.
- Verified: yes - the typo is on the cited line; the fix is one word.

### F2 - [Important] src/export/pdf.ts:120 (base)

- Claim: `page.footer` is dereferenced without a null check at line 120.
- Code reality: `src/export/pdf.ts` has 64 lines, and no line in it
  mentions `footer`.
- Verified: no - citation invalid.

### F3 - [Important] src/export/csv.ts:40 (base)

- Claim: `papaparse`'s `unparse()` drops the header row when the `columns`
  option is passed, so the exported CSV has no headers.
- Code reality: line 40 calls `Papa.unparse(rows, { columns })`. The
  Context7 lookup for `papaparse` returned no match, and the fetch of the
  library's docs page returned HTTP 503 twice.
- Verified: unconfirmed - couldn't load papaparse's docs to check how
  `columns` affects the header row.

### F4 - [Important] src/api/routes.ts:15 (base)

- Claim: the new download route is `GET /exports/:id/download`, but the
  plan's endpoint table names it `GET /exports/:id/file`.
- Code reality: line 15 registers `router.get("/exports/:id/download", ...)`.
  The plan's endpoint table says `GET /exports/:id/file`, and its Decisions
  don't mention a change. `/download` reads well and works.
- Verified: yes - the route differs from the plan's endpoint table.

## Question

Apply Step 7 to F1-F4. Give each finding's bucket.

```json
{
  "findings": [
    {
      "id": "F1",
      "bucket": "auto-fix | auto-skip | needs-review | logged-polish",
      "reason": "<one line>"
    }
  ]
}
```
