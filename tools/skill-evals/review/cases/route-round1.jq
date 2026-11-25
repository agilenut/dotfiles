def bucket($id): [.findings[]? | select(.id == $id) | .bucket] | first;
[
  { name: "F1 typo on a line the diff added is auto-fix", ok: (bucket("F1") == "auto-fix") },
  { name: "F2 invalid citation is auto-skip", ok: (bucket("F2") == "auto-skip") },
  { name: "F3 unconfirmed is needs-review", ok: (bucket("F3") == "needs-review") },
  { name: "F4 plan deviation is needs-review", ok: (bucket("F4") == "needs-review") }
]
| map(select(.ok != true) | .name)
