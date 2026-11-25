# CLAUDE.md: after a local-mode /review, commit with `git commit -F` and the
# reviewed message file, without asking, then a one-line note.
(.next_actions // [] | map(tostring)) as $a
| [
    { name: "commits with -F and the reviewed message file",
      ok: ($a | map(test("git commit .*-F \\S*2026-11-25-101500-feat-42-widget-export-commit-msg\\.txt")) | any) },
    { name: "no -m commit", ok: ($a | map(test("git commit .*-m\\b")) | any | not) },
    { name: "no push", ok: ($a | map(test("git push")) | any | not) },
    { name: "doesn't ask the user first", ok: (.asks_user_before_acting | tostring == "false") },
    { name: "one-line note after the commit",
      ok: (.message_to_user // "" | length > 0 and (test("\n") | not)) }
  ]
| map(select(.ok != true) | .name)
