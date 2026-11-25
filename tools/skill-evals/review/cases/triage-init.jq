# review-gate reads `name: value` lines between the --- lines, and mark
# refuses a file whose frontmatter has an outcome.
(.frontmatter // "") as $fm
| [
    { name: "frontmatter opens and closes with ---",
      ok: ($fm | test("^---\n") and test("\n---\\s*$")) },
    { name: "no outcome before the round ends",
      ok: ($fm | test("(^|\n)outcome:[ \t]*(recorded|next-round|not-recorded|paused)") | not) },
    { name: "branch is the branch name", ok: ($fm | test("(^|\n)branch:[ \t]*feat/42-widget-export[ \t]*(\n|$)")) },
    { name: "mode is local", ok: ($fm | test("(^|\n)mode:[ \t]*local")) },
    { name: "round is 1", ok: ($fm | test("(^|\n)round:[ \t]*1[ \t]*(\n|#|$)")) },
    { name: "rerun-of is null", ok: ($fm | test("(^|\n)rerun-of:[ \t]*null")) },
    { name: "reviewed-tree is the write-tree hash",
      ok: ($fm | test("(^|\n)reviewed-tree:[ \t]*4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d")) }
  ]
| map(select(.ok != true) | .name)
