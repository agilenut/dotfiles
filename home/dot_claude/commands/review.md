---
title: Review Command
description: Review code changes for bugs, security issues, and quality
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git show:*), Read, Grep, Glob
---

Review the specified code changes. Be critical and thorough.

## Scope

$ARGUMENTS

**Default** (no arguments): Review current branch compared to main.

**Examples of valid scopes:**

- `--staged` - Review staged changes (pre-commit review)
- `<file path>` - Review a specific file
- `HEAD~3..HEAD` - Review last 3 commits
- `main..feature-branch` - Review specific branch comparison
- "the code we just wrote" - Review recent session changes (use context)

If the scope is unclear, ask for clarification before proceeding.

## Review Checklist

1. **Security**
   - Injection vulnerabilities (SQL, command, XSS)
   - Secrets or credentials exposed
   - PII handling issues
   - Authentication/authorization gaps

2. **Correctness**
   - Logic errors and edge cases
   - Off-by-one errors
   - Null/undefined handling
   - Race conditions

3. **Quality**
   - Unnecessary complexity
   - Code duplication
   - Missing error handling
   - Unclear naming or structure

4. **Performance**
   - Obvious inefficiencies
   - N+1 queries
   - Unnecessary allocations

5. **Testing**
   - Are new code paths tested?
   - Are edge cases covered?

## Output Format

For each issue found:

- **File:line** - Brief description
- Severity: critical/warning/suggestion
- Recommended fix

End with a summary: approve, request changes, or needs discussion.
