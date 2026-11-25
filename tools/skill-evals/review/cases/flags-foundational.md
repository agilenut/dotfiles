# Review skill case

## Facts

- Repo `acme-widgets`, branch `feat/42-widget-export`. Round 1, local
  mode. No plan file, no review-preferences files, no prior triage.
- The diff adds `config/export-settings.json` and `src/export/settings.ts`,
  which reads and validates it.
- Reviewers `base-reviewer` and `language-reviewer` both wrote valid
  output. Step 7's bucket criteria gave these buckets; the second-pass
  flags haven't run yet.

| id  | severity   | finding                                                                                                                  | bucket       |
| --- | ---------- | ------------------------------------------------------------------------------------------------------------------------ | ------------ |
| G1  | Important  | Consider YAML instead of JSON for export settings: the file needs comments, which JSON can't hold                        | needs-review |
| G2  | Important  | `settings.ts:22` catches `JSON.parse` errors but drops the message, so a bad file gives "invalid settings" with no line  | needs-review |
| G3  | Suggestion | `config/export-settings.json:4` key `"delimter"` is misspelled; `settings.ts` reads `delimiter`, so the value is ignored | auto-fix     |
| G4  | Suggestion | `settings.ts:40` hand-rolls the JSON schema check that the `ajv` package already in the project does                     | needs-review |
| G5  | Suggestion | `src/export/csv.ts:88` error message says "wirte" instead of "write"                                                     | auto-fix     |

If the user takes G1, the file becomes YAML: G2's `JSON.parse` handling,
G3's JSON key, and G4's JSON schema check all change or go away. G5 is
unrelated to the settings file.

## Question

Run the second-pass flags, then say which runs first after Step 8: the
Step 9 dialog or the Step 10 auto-fixes.

```json
{
  "foundational": ["<ids marked foundational: true>"],
  "buckets_after_flags": {
    "G1": "<bucket>",
    "G2": "<bucket>",
    "G3": "<bucket>",
    "G4": "<bucket>",
    "G5": "<bucket>"
  },
  "runs_first": "step-9-dialog | step-10-auto-fixes"
}
```
