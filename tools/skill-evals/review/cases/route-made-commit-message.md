# Review skill case

## Facts

- Repo `acme-widgets`, branch `feat/42-widget-export`. Round 1, **branch
  mode** (`/review branch`). The branch has three commits since `<base>`;
  none is pushed.
- No plan file. `~/.claude/review-preferences.md` holds one rule:
  `Auto-fix commit message findings; I never want to be asked about wording.`
- Reviewers `base-reviewer` and `language-reviewer` both wrote valid
  output. Step 6 wrote these lines for the only finding.

### M1 - [Suggestion] commit 3f9c2a1 (language)

- Claim: the commit title "fixed stuff" doesn't say what changed and isn't
  in the imperative mood the global CLAUDE.md asks for.
- Code reality: `git log -1 --format=%B 3f9c2a1` prints "fixed stuff" with
  no body. The commit changes the CSV column order.
- Verified: yes - checked against `git log -1 --format=%B 3f9c2a1`.

## Question

Decide what this run does with M1: where it goes, whether the review
changes the commit, and whether you ask the user about it during the run.

```json
{
  "id": "M1",
  "destination": "auto-fix | auto-skip | needs-review | logged-polish | commit-messages",
  "review_changes_the_commit": "<true | false>",
  "asked_during_dialog": "<true | false>"
}
```
