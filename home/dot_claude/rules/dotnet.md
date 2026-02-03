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

## VS Code Extensions

- ms-dotnettools.csdevkit
- csharpier.csharpier-vscode
- esbenp.prettier-vscode
- editorconfig.editorconfig
- davidanson.vscode-markdownlint

## VS Code Settings

```json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "[csharp]": {
    "editor.defaultFormatter": "csharpier.csharpier-vscode"
  }
}
```

This ensures VS Code and pre-commit both use CSharpier for consistent formatting.

## EditorConfig

Base rules:

- `[*.cs]`: 4-space indent
- `csharp_style_namespace_declarations = file_scoped:error`
- `csharp_style_var_for_built_in_types = true:suggestion`
- StyleCop rules with `severity = error` (specific rules TBD)
- Only add sections for file types that actually exist in the project

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
