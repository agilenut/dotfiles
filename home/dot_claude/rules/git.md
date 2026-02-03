# Git Rules

## Workflow

- **New projects**: Suggest a repo name (allow override), init with language-appropriate .gitignore.
- **Existing folders without git**: Suggest initializing before making changes.
- **Protected branches** (main, master, develop, dev): Never commit directly. Create a feature branch first.
- **Branch naming**: Use prefixes (feature/, fix/, refactor/, etc.) and suggest a name for approval.
- **On a feature branch**:
  - Related work: continue on current branch.
  - Unrelated work: suggest committing current changes, then create a new branch.
- **Uncommitted changes before switching**: Suggest commit first.
- **Atomic progress**: When work is tested and functional, suggest committing to the feature branch.
- **Commit approval flow**: Always display the proposed commit message in chat and wait for explicit approval (e.g., "yes", "approve", "go") before running `git commit`. Never rely on the permission popup for review - it's hard to read.

## Rules

- No co-authoring attribution.
- No "Generated with Claude Code" or similar footers in PRs.
- Never modify history unless explicitly instructed.

## Commit Format

```text
Brief summary of change

One to two short paragraphs with context, reasoning, or details. Prefer bullets.
```

## Gitignore Management

Project .gitignore files must be **explicit and self-contained**. Don't rely on global gitignore - other devs won't have it.

When creating project .gitignore files:

- .NET: Use `dotnet new gitignore` (built into SDK)
- Other languages: Use `npx gitignore <language>` (node, python, etc.) - github/gitignore is maintained
- Prune legacy patterns: VS6 artifacts, Vista thumbnails, Cygwin stackdumps, AFP shares
- Include OS patterns (macOS: `.DS_Store`, `._*`; Windows: `Thumbs.db`, `Desktop.ini`)
- Always include secrets: `*.pem`, `*.key`, `*_rsa`, `*.p12`, `*.pfx`, `*.jks`, `credentials.json`, `secrets.json`, `service-account*.json`, `.env`, `.env.*`, `!.env.example`
- Add `.idea/` for JetBrains, `.claude/settings.local.json` for Claude Code

**Section ordering** (most specific to most generic):

1. **Language/Framework** - build artifacts, dependencies (alphabetical if multi-language)
2. **Testing** - coverage, test results
3. **IDEs/Editors** - .idea/, .claude/, \*.swp
4. **Secrets/Credentials** - .env, \*.pem, keys (easy to audit)
5. **OS Files** - Linux, macOS, Windows (alphabetical)
