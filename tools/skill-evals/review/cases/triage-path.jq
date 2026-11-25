# review-gate mark accepts only .reviews/code/<YYYY-MM-DD-HHMMSS>-<branch with
# each / as ->-triage.md. A path that keeps the slash puts the file in a
# subfolder, and mark refuses it.
[
  { name: "path is the name review-gate accepts (slash in the branch becomes -)",
    ok: (.triage_path // "" | test("^\\.reviews/code/2026-11-25-101500-feat-42-widget-export-triage\\.md$")) }
]
| map(select(.ok != true) | .name)
