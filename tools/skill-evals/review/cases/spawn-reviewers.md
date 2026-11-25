# Review skill case

## Facts

- Repo `acme-widgets`, branch `feat/42-widget-export`. `/review` with no
  arguments; the tree has uncommitted changes, so this is round 1 in
  local mode.
- This session's model is `claude-opus-5-5`.
  `echo "$CLAUDE_CODE_SUBAGENT_MODEL"` prints an empty line.
- Step 2 timestamp: `2026-11-25-101500`. Commit message draft:
  `.reviews/code/2026-11-25-101500-feat-42-widget-export-commit-msg.txt`.
- The diff (about 60 lines) changes two files:
  - `home/dot_claude/skills/widget-sync/SKILL.md`: adds a step telling the
    model to retry a failed sync once, then report the error.
  - `docs/widget-sync.md`: adds a matching paragraph for readers.
- No other file changes. No plan file matches.

## Question

You are at Step 3. List the Agent calls you make: each one's
`subagent_type`, its output path, and whether its prompt includes the
session model ID. Say whether they go in one message, and give the
mandatory write rule line exactly as you put it in each prompt.

```json
{
  "agents": [
    {
      "subagent_type": "<type>",
      "output_path": "<path>",
      "includes_model_id": "<true | false>"
    }
  ],
  "all_in_one_message": "<true | false>",
  "mandatory_write_rule": "<the exact line>"
}
```
