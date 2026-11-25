# A finding the user already skipped is settled by the carry-over check, so
# the pattern-wide flag mustn't move it to needs-review and ask again.
[
  { name: "the user's earlier skip carries: auto-skip", ok: (.bucket == "auto-skip") },
  { name: "a settled finding gets no pattern-wide flag", ok: (.pattern_wide | tostring == "false") },
  { name: "reason says the user skipped it before",
    ok: (.reason // "" | test("previously skipped by user"; "i")) }
]
| map(select(.ok != true) | .name)
