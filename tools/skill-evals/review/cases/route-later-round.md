# Review skill case

## Facts

- Repo `acme-widgets`, branch `feat/42-widget-export`. **Round 2**, local
  mode. Round 1 made fixes that changed behavior, so Step 14 started this
  round. Round 2 reviews the whole scope plus round 1's fixes.
- No plan file, no review-preferences files. Round 1's triage has no
  user-driven skips.
- Reviewers `base-reviewer`, `language-reviewer`, and `ai-reviewer` all
  wrote valid output. Step 6 wrote these lines.

### L1 - [Suggestion] skills/widget-sync/SKILL.md:40 (ai)

- Claim: the paragraph at lines 40-44, which tells the model to retry a
  failed sync once and then report the error, could read more smoothly;
  the reviewer offers a reworded version of the paragraph.
- Code reality: the paragraph says "If the sync fails, retry it once. If
  the retry also fails, stop and report the error with the command's
  output." It has one reading, and the reviewer names no way a model
  would follow it wrongly. The rewording says the same thing in a
  different order.
- Verified: yes - the rewording is accurate; the current text is also
  correct and unambiguous.

### L2 - [Important] src/export/csv.ts:52 (base)

- Claim: round 1's fix changed the loop bound from `i < rows.length - 1`
  to `i <= rows.length`, so the loop reads one past the end of `rows`.
- Code reality: line 52 is `for (let i = 0; i <= rows.length; i++)`, and
  line 53 reads `rows[i].values`. On the last pass `rows[i]` is
  `undefined`, so the export throws a TypeError.
- Verified: yes - every export with at least one row fails.

### L3 - [Suggestion] src/export/csv.ts:50 (language)

- Claim: the comment round 1's fix added says "recieve" instead of
  "receive".
- Code reality: line 50 is `// rows we recieve are already sorted`.
- Verified: yes - one-word typo in a comment.

## Question

Apply Step 7 to L1-L3. Give each finding's bucket.

```json
{
  "findings": [
    {
      "id": "L1",
      "bucket": "auto-fix | auto-skip | needs-review | logged-polish",
      "reason": "<one line>"
    }
  ]
}
```
