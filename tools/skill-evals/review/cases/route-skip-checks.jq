def entry($id): [.findings[]? | select(.id == $id)] | first // {};
[
  { name: "P1 matching a skip preference is auto-skip",
    ok: (entry("P1").bucket == "auto-skip") },
  { name: "P1 reason cites the preference",
    ok: (entry("P1").reason // "" | test("matches review-preference"; "i")) },
  { name: "P2 skipped by the user before is auto-skip",
    ok: (entry("P2").bucket == "auto-skip") },
  { name: "P2 reason says the user skipped it before",
    ok: (entry("P2").reason // "" | test("previously skipped by user"; "i")) },
  { name: "P3 prior auto-skip isn't carried",
    ok: (entry("P3").reason // "" | test("previously skipped"; "i") | not) },
  { name: "P3 is bucketed fresh as auto-fix",
    ok: (entry("P3").bucket == "auto-fix") }
]
| map(select(.ok != true) | .name)
