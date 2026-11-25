# One check only: the skill settles that round 1 doesn't log polish, but not
# which bucket this rewording gets (a reasonable reviewer could argue
# auto-fix, auto-skip, or needs-review). Don't tighten it to one bucket.
def bucket($id): [.findings[]? | select(.id == $id) | .bucket] | first;
[
  { name: "L1 gets a bucket (round 1 has no later-round sort)",
    ok: (bucket("L1") | IN("auto-fix", "auto-skip", "needs-review")) }
]
| map(select(.ok != true) | .name)
