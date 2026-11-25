# Review skill case

## Facts

- Repo `acme-widgets`, branch `feat/42-widget-export`. Round 1, local
  mode. Reviewers `base-reviewer` and `language-reviewer` both wrote valid
  output.
- Step 5 is extracting findings. These are every bullet in the two
  reports:

From `base-reviewer`:

- B1 - [Suggestion] docs/export.md:20-34: the "Export formats" section
  lists each format in one line; add a short example output for each of
  the three formats so readers can see what they get.
- B2 - [Important] src/export/csv.ts:52: the loop bound `i <= rows.length`
  reads one past the end of `rows`.

From `language-reviewer`:

- G1 - [Important] docs/export.md:20-34: the "Export formats" section is
  already long for an overview; cut it to the list of format names and
  link to the reference page.

## Question

Apply Step 5 to these bullets. List the atomic findings it produces.

```json
{
  "entries": [
    {
      "sources": ["B1"],
      "reviewers": ["base"],
      "file": "<path>",
      "severity": "Critical | Important | Suggestion",
      "fixes": ["<each fix the entry lists>"]
    }
  ]
}
```
