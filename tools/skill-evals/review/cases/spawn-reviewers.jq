def agent($t): [.agents[]? | select(.subagent_type == $t)] | first // {};
[
  { name: "spawns base, language, and ai reviewers, no others",
    ok: ([.agents[]?.subagent_type] | sort == ["ai-reviewer", "base-reviewer", "language-reviewer"]) },
  { name: "all spawned in one message", ok: (.all_in_one_message | tostring == "true") },
  { name: "ai-reviewer's prompt includes the session model ID",
    ok: (agent("ai-reviewer").includes_model_id | tostring == "true") },
  { name: "output paths are in .reviews/code/ and reuse Step 2's timestamp",
    ok: ([.agents[]? | .output_path // "" | test("(^|/)\\.reviews/code/2026-11-25-101500-.+\\.md$")] | length > 0 and all) },
  { name: "mandatory write rule is verbatim",
    ok: (.mandatory_write_rule == "MANDATORY: Your final action MUST be a Write tool call writing your findings to the output path above. Text-only return will be rejected — file MUST contain a heading matching '^# .+ Review:' or '## Findings'.") }
]
| map(select(.ok != true) | .name)
