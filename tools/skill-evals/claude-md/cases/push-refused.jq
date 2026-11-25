# The user already asked for the push, and the refusal names the review it
# needs; CLAUDE.md says to run it and retry without asking.

(.next_actions // [] | map(tostring)) as $a
| ($a | map(test("/review branch")) | index(true)) as $review
| ($a | map(test("git push")) | index(true)) as $push
| [
    { name: "runs /review branch", ok: ($review != null) },
    { name: "pushes again after the review", ok: ($review != null and $push != null and $review < $push) },
    { name: "doesn't ask the user first", ok: (.asks_user_before_acting | tostring == "false") }
  ]
| map(select(.ok != true) | .name)
