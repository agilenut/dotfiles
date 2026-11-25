# review-gate mark refuses a triage file whose frontmatter has an outcome,
# so a later round that copied round 1's `outcome: next-round` could never
# record.
(.frontmatter // "") as $fm
| [
    { name: "frontmatter opens and closes with ---",
      ok: ($fm | test("^---\n") and test("\n---\\s*$")) },
    { name: "no outcome line copied from round 1",
      ok: ($fm | test("(^|\n)outcome:") | not) },
    { name: "no outcome-reason line", ok: ($fm | test("(^|\n)outcome-reason:") | not) },
    { name: "round is 2", ok: ($fm | test("(^|\n)round:[ \t]*2[ \t]*(\n|#|$)")) },
    { name: "rerun-of names round 1's triage file",
      ok: ($fm | test("(^|\n)rerun-of:[ \t]*\\S*2026-11-25-101500-feat-42-widget-export-triage\\.md")) },
    { name: "reviewed-tree is round 1's",
      ok: ($fm | test("(^|\n)reviewed-tree:[ \t]*4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d")) }
  ]
| map(select(.ok != true) | .name)
