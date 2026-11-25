def status($i): .statuses[$i] // "" | sub("^Status: "; "");
[
  { name: "the answered fix is applied before exiting", ok: (status("4") | startswith("fixed (user-confirmed)")) },
  { name: "the answered skip is recorded", ok: (status("5") | startswith("skipped (user accepted SKIP)")) },
  { name: "the question on screen stays pending", ok: (status("6") == "pending") },
  { name: "the unasked question stays pending", ok: (status("7") == "pending") },
  { name: "outcome is paused", ok: (.outcome == "paused") },
  { name: "a pause records nothing", ok: (.runs_review_gate_mark | tostring == "false") },
  { name: "it prints the pause message with the question and fix counts",
    ok: (.printed // "" | test("^Paused at question 3 of 4; 1 answered fixes? applied\\.")) }
]
| map(select(.ok != true) | .name)
