[
  { name: "only G1 is foundational", ok: ((.foundational // []) == ["G1"]) },
  { name: "foundational doesn't change G1's bucket", ok: (.buckets_after_flags.G1 == "needs-review") },
  { name: "the foundational dialog runs before the auto-fixes", ok: (.runs_first == "step-9-dialog") }
]
| map(select(.ok != true) | .name)
