---
description: Systematically diagnose and fix an issue
argument-hint: [description of the problem]
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

Troubleshoot the issue: $ARGUMENTS

## Approach

1. **Reproduce**: Understand and confirm the problem
2. **Gather evidence**: Error messages, logs, recent changes, environment
3. **Hypothesize**: List 2-3 likely causes, rank by probability
4. **Test hypotheses**: Start with most likely, isolate variables
5. **Fix root cause**: Don't fix symptoms or add workarounds
6. **Verify**: Confirm fix works, no regressions, tests pass

## Output

After each step, briefly report what you did, what you found, next action.

Ask clarifying questions if needed rather than guessing.
