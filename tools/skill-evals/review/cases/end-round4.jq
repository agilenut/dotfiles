[
  { name: "no fifth round", ok: (has("starts_round") and (.starts_round | tostring == "null")) },
  { name: "it records nothing", ok: (has("mark_command") and (.mark_command == null or .mark_command == "")) },
  { name: "outcome is not-recorded", ok: (.outcome == "not-recorded") },
  { name: "outcome-reason is set", ok: ((.outcome_reason // "") | length > 0) },
  { name: "record line says four rounds kept changing behavior",
    ok: (.record_line // "" | test("^Not recorded: four rounds of fixes kept changing behavior")) }
]
| map(select(.ok != true) | .name)
