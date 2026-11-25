[
  { name: "a rename with 2+ other occurrences is pattern-wide", ok: (.pattern_wide | tostring == "true") },
  { name: "pattern-wide forces needs-review", ok: (.bucket == "needs-review") },
  { name: "it counts the three other occurrences", ok: (.other_occurrences | tostring == "3") }
]
| map(select(.ok != true) | .name)
