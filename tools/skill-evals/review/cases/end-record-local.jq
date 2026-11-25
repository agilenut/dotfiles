[
  { name: "behavior-neutral fixes don't start another round", ok: (.next_round_due | tostring == "false") },
  { name: "local mode marks without --branch, naming the triage file",
    ok: (.mark_command // "" | test("^review-gate mark \\S*2026-11-25-101500-feat-42-widget-export-triage\\.md$")) },
  { name: "outcome is recorded", ok: (.outcome == "recorded") },
  { name: "record line is 'Recorded: review of tree <12 chars>'",
    ok: (.record_line // "" | startswith("Recorded: review of tree 1a2b3c4d5e6f")) }
]
| map(select(.ok != true) | .name)
