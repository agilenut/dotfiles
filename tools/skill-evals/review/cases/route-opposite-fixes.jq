def merged: [.entries[]? | select((.sources // []) | (index("B1") != null and index("G1") != null))] | first;
[
  { name: "three bullets become two entries", ok: ((.entries // []) | length == 2) },
  { name: "B1 and G1 (opposite fixes on the same text) are one entry", ok: (merged != null) },
  { name: "the merged entry takes the higher severity (Important)",
    ok: (merged.severity // "" | test("^important$"; "i")) },
  { name: "the merged entry lists both fixes", ok: ((merged.fixes // []) | length >= 2) },
  { name: "the merged entry lists both reviewers", ok: ((merged.reviewers // []) | length >= 2) }
]
| map(select(.ok != true) | .name)
