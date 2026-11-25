[
  { name: "something staged at the start of a branch review means no record",
    ok: (has("mark_command") and (.mark_command == null or .mark_command == "")) },
  { name: "outcome is not-recorded", ok: (.outcome == "not-recorded") },
  { name: "record line starts 'Not recorded:'",
    ok: (.record_line // "" | startswith("Not recorded:")) }
]
| map(select(.ok != true) | .name)
