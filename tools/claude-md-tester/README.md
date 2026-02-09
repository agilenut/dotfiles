# CLAUDE.md A/B Tester

Tests whether each instruction in `~/.claude/CLAUDE.md` actually changes Claude's behavior, so you can trim the ones that don't and save context tokens.

## How It Works

For each instruction in your CLAUDE.md:

1. **Full**: Runs prompts with all instructions present
2. **Ablated**: Runs prompts with that one instruction removed
3. **Bare**: Runs prompts with an empty CLAUDE.md (baseline)

Compares outputs across conditions to determine if the instruction has a measurable effect.

## Prerequisites

- `claude` CLI (Claude Code) with an active subscription
- `jq` for JSON processing

## Quick Start

```bash
# Dry run to see what would execute
./run_tests.sh --dry-run

# Test a single instruction quickly (2 runs)
./run_tests.sh --filter concise --runs 2

# Full test suite with Opus
./run_tests.sh --model opus --runs 5

# Analyze results
./analyze.sh
```

## Options

```text
--model MODEL       Claude model (default: opus). Also: sonnet, haiku
--runs N            Runs per condition (default: 5)
--concurrency N     Parallel claude -p calls (default: 3)
--filter ID         Test only one instruction by ID
--dry-run           Preview without executing
--clean             Remove previous results first
```

## Output

Results are saved to `results/` with this structure:

```text
results/
├── {instruction_id}/
│   ├── full/{prompt_hash}/run_{N}.json
│   ├── ablated/{prompt_hash}/run_{N}.json
│   └── bare/{prompt_hash}/run_1.json
└── report.md
```

`report.md` contains a summary table with effect ratings and side-by-side response comparisons.

## Adding Test Cases

Edit `test_definitions.json` to add or modify test cases. Each entry needs:

- `id`: Unique identifier (used for result directories)
- `instruction`: The exact text from CLAUDE.md
- `line`: Line number in CLAUDE.md (1-indexed)
- `prompts`: Array of test prompts that would reveal the instruction's effect
- `scoring`: Metrics and patterns for automated evaluation

## Limitations

**Agentic vs print mode**: `claude -p` produces short, focused responses where
Claude pays full attention to formatting. In real agentic sessions (long context,
many tool calls), Claude may be sloppier about details like code block language
tags or response conciseness. A "Low" result here means the instruction doesn't
change behavior in ideal conditions — it may still help in degraded conditions.

**5 untestable instructions**: Some instructions govern tool-use behavior (plan
mode, branching, test deletion, etc.) that can't be triggered in print mode.
These require manual spot-checking in real interactive sessions.

**Prompt design matters**: Test prompts that hint at the "correct" answer will
mask an instruction's effect. Review prompts carefully — if the prompt makes the
desired behavior obvious, Claude will exhibit it regardless of the instruction.

## Cost

All calls use your Claude Code subscription. Estimated runs for the full suite:

| Model  | Runs | Total Calls | Wall Time (~) |
| ------ | ---- | ----------- | ------------- |
| Haiku  | 5    | ~374        | ~15 min       |
| Sonnet | 5    | ~374        | ~30 min       |
| Opus   | 5    | ~374        | ~60 min       |
