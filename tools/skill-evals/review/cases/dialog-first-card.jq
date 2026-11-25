(.printed // "") as $p
| ($p | split("\n") | map(select(test("\\S"))) | last // "") as $last
| [
    { name: "opening summary line comes first, with the right counts",
      ok: ($p | test("^\\s*Fixed 2, skipped 1, 3 questions for you, out of 6 findings\\.")) },
    { name: "card header names the item", ok: ($p | test("Needs your call \\(item #4\\)")) },
    { name: "card offers f/s/c", ok: ($p | test("\\(f\\)ix / \\(s\\)kip / \\(c\\)ontext")) },
    { name: "card has the pattern line", ok: ($p | test("(^|\n)Pattern: ")) },
    { name: "a SKIP take on a pattern-wide item says why it is surfaced",
      ok: ($p | test("(^|\n)Why surfacing this: ")) },
    { name: "status line is last and counts question 1 of 3",
      ok: ($last | test("review questions \\(1 of 3\\) · need: f/s/c\\s*$")) }
  ]
| map(select(.ok != true) | .name)
