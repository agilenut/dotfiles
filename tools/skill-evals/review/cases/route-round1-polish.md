# Review skill case

## Facts

- Repo `acme-widgets`, branch `feat/42-widget-export`. **Round 1**, local
  mode. The diff adds `skills/widget-sync/SKILL.md`.
- No plan file, no review-preferences files, no prior triage.
- Reviewers `base-reviewer`, `language-reviewer`, and `ai-reviewer` all
  wrote valid output. Step 6 wrote these lines for the only finding.

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

## Question

Apply Step 7 to L1. Give its bucket.

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
