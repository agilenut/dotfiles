[
  { name: "a failed reviewer means no record", ok: (has("mark_command") and (.mark_command == null or .mark_command == "")) },
  { name: "outcome is not-recorded", ok: (.outcome == "not-recorded") },
  { name: "outcome-reason names the security reviewer",
    ok: (.outcome_reason // "" | test("security"; "i")) },
  { name: "record line starts 'Not recorded:'",
    ok: (.record_line // "" | startswith("Not recorded:")) }
]
| map(select(.ok != true) | .name)
