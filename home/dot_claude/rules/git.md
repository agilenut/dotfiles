# Git Rules

## Project Setup

- **New projects**: Suggest repo name, init with language-appropriate .gitignore
- **Existing folders without git**: Suggest initializing before making changes

## Workflow

- Before suggesting commit, verify work is functional (build/test/lint/scripts as needed)

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
