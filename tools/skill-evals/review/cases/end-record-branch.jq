[
  { name: "branch mode stages only the files a fix touched", ok: (.staged_paths == ["README.md"]) },
  { name: "branch mode marks with --branch, naming the triage file",
    ok: (.mark_command // "" | test("^review-gate mark --branch \\S*2026-11-25-101500-feat-42-widget-export-triage\\.md$")) },
  { name: "outcome is recorded", ok: (.outcome == "recorded") },
  { name: "record line is 'Recorded: review of tree <12 chars>'",
    ok: (.record_line // "" | startswith("Recorded: review of tree 9f8e7d6c5b4a")) }
]
| map(select(.ok != true) | .name)
