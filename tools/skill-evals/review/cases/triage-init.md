# Review skill case

## Facts

- Repo `acme-widgets`, branch `feat/42-widget-export`. Round 1, local
  mode. Step 2's timestamp: `2026-11-25-101500`.
- Step 1's starting state (`git status --short`):

  ```text
   M src/export/csv.ts
  ```

- Plan file: `.plans/widget-export.md`.
- Reviewers that ran: base, language. `git write-tree` after Step 2's
  staging printed `4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d`.
- Step 7 bucketed one auto-fix and one auto-skip; no needs-review items.

## Question

You are at Step 8. Give the triage file's frontmatter exactly as you
write it now, from the opening `---` to the closing `---`.

```json
{
  "frontmatter": "<the frontmatter text, as a JSON string>"
}
```
