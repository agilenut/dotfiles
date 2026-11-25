# Review skill case

## Facts

- Repo `acme-widgets`, branch `feat/42-widget-export`. Round 1, local
  mode. Triage file:
  `.reviews/code/2026-11-25-101500-feat-42-widget-export-triage.md`.
- Step 12 dialog with four needs-review questions (no foundational
  items):
  - Question 1, item #4: `My take: FIX`. The user answered `f`.
  - Question 2, item #5: `My take: SKIP`. The user answered `s`.
  - Question 3, item #6 is on screen. The user typed `stop`.
  - Question 4, item #7 hasn't been asked.
- Item #4's fix is a one-line change in `src/export/csv.ts`; it hasn't been
  applied yet, since fixes wait until the last answer. If you apply it,
  assume the build passes.

## Question

What does the skill do now? Give each item's status in the triage file
after you finish, the triage frontmatter's `outcome:`, whether you run
`review-gate mark`, and the text you print.

```json
{
  "statuses": {
    "4": "<Status: value>",
    "5": "<...>",
    "6": "<...>",
    "7": "<...>"
  },
  "outcome": "recorded | next-round | not-recorded | paused | <none>",
  "runs_review_gate_mark": "<true | false>",
  "printed": "<the text you print, exactly>"
}
```
