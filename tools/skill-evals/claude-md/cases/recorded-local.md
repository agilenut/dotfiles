# CLAUDE.md case

## Facts

- Repo `acme-widgets` at `/home/dev/acme-widgets`, branch
  `feat/42-widget-export`. The user asked you to fix the rounding in the
  CSV export. You made the change and ran `/review` on it, in local mode.
  The user didn't ask for a push.
- `/review` finished. The last lines of its final summary are:

  ```text
  Triage: .reviews/code/2026-11-25-101500-feat-42-widget-export-triage.md

  Build green.
  Recorded: review of tree 1a2b3c4d5e6f. Any further edit needs
  a new review before it can be committed.
  Local mode: commit with the reviewed message in
  /home/dev/acme-widgets/.reviews/code/2026-11-25-101500-feat-42-widget-export-commit-msg.txt.
  ```

- `git status --short` shows `M  src/export/csv.ts` (staged, no later
  edits).

## Question

What do you do next? List each command you run, in order, say whether you
ask the user anything first, and give what you tell the user after.

```json
{
  "next_actions": ["<each command, in order>"],
  "asks_user_before_acting": "<true | false>",
  "message_to_user": "<what you tell the user after, or null>"
}
```
