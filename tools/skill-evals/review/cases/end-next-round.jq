[
  { name: "a fix that changed behavior makes round 2 due", ok: (.next_round_due | tostring == "true") },
  { name: "it starts round 2", ok: ((.starts_round | tostring) == "2") },
  { name: "it starts round 2 without asking", ok: (.asks_user_before_next_round | tostring == "false") },
  { name: "it records nothing", ok: (has("mark_command") and (.mark_command == null or .mark_command == "")) },
  { name: "outcome is next-round", ok: (.outcome == "next-round") },
  { name: "record line is the exact next-round line",
    ok: (.record_line == "Fixes changed behavior; starting round 2 of at most 4.") },
  { name: "next triage has round: 2", ok: ((.next_triage_round_field | tostring) == "2") },
  { name: "next triage's rerun-of names this round's triage",
    ok: (.next_triage_rerun_of // "" | test("2026-11-25-101500-feat-42-widget-export-triage\\.md$")) }
]
| map(select(.ok != true) | .name)
