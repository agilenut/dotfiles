---
paths:
  - "**/*.cs"
  - "**/*.csproj"
  - "**/*.sln"
  - "**/Directory.Build.props"
---

# C# / .NET Archetype

## New Project Setup

When creating a new .NET project, always set up:

- `.editorconfig` (4-space indent for C#, StyleCop rules)
- `.vscode/extensions.json` and `.vscode/settings.json`
- `.markdownlint.yaml` (MD013: false)
- `.pre-commit-config.yaml`
- StyleCop.Analyzers NuGet package
- CSharpier (dotnet tool)
- `.gitignore` (use `dotnet new gitignore`)

## Formatting & Linting

- Formatter: CSharpier (zero config, opinionated)
- Linter: StyleCop.Analyzers NuGet package
- Run via: `dotnet format` (integrates both)
- Never disable, suppress, or modify StyleCop or analyzer rules without asking first

## Pre-commit Hooks

- prettier (markdown, JSON, YAML)
- dotnet-format
- dotnet-build
- dotnet-test (if test projects exist)
- markdownlint
- gitleaks

## Testing

Test projects (`*.Tests`) - relaxed rules:

- SA1600 series (XML docs): disabled or warning
- SA1300 (underscore in names): allow for BDD-style test names
- VSTHRD200 (async naming): relaxed

Production code: full StyleCop enforcement
