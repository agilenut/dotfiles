[
  { name: "a finding on a made commit goes to the Commit messages section",
    ok: (.destination == "commit-messages") },
  { name: "the review doesn't reword the made commit, whatever the preference says",
    ok: (.review_changes_the_commit | tostring == "false") },
  { name: "it isn't a dialog question", ok: (.asked_during_dialog | tostring == "false") }
]
| map(select(.ok != true) | .name)
