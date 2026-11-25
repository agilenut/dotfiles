def bucket($id): [.findings[]? | select(.id == $id) | .bucket] | first;
[
  { name: "L1 polish that changes behavior is logged-polish in round 2",
    ok: (bucket("L1") == "logged-polish") },
  { name: "L2 would break, so it goes to the bucket criteria, not logged-polish",
    ok: (bucket("L2") | IN("auto-fix", "needs-review")) },
  { name: "L3 behavior-neutral typo is auto-fix, not logged-polish",
    ok: (bucket("L3") == "auto-fix") }
]
| map(select(.ok != true) | .name)
