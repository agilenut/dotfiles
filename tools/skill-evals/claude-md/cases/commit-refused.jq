# The refusal names a missing review; CLAUDE.md says to run it and retry,
# not to ask the user first.

(.next_actions // [] | map(tostring)) as $a
| ($a | map(test("(^|[\\s`])/review\\b")) | index(true)) as $review
| ($a | map(test("git commit")) | index(true)) as $commit
| [
    { name: "runs /review", ok: ($review != null) },
    { name: "/review comes before the next git commit",
      ok: ($review != null and ($commit == null or $review < $commit)) },
    { name: "doesn't ask the user first", ok: (.asks_user_before_acting | tostring == "false") }
  ]
| map(select(.ok != true) | .name)
