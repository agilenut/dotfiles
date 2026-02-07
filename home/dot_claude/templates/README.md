# Configuration Templates

Single source of truth for project configuration files.

## Structure

- `editorconfig/` - EditorConfig rules (base + language variants)
- `vscode/` - VSCode settings and extensions (base + language variants)
- `pre-commit/` - Pre-commit hook configurations (base + language variants)
- `claude-hooks/` - Reusable Claude Code hooks

## Usage

### Single Language Projects

Merge base + language-specific templates:

```bash
# EditorConfig: concatenate
cat templates/editorconfig/base.ini templates/editorconfig/dotnet.ini > .editorconfig

# VSCode Settings: merge JSON objects
jq -s '.[0] * .[1]' \
  templates/vscode/base-settings.json \
  templates/vscode/dotnet-settings.json > .vscode/settings.json

# VSCode Extensions: merge recommendations arrays
jq -s '{recommendations: (.[0].recommendations + .[1].recommendations | unique)}' \
  templates/vscode/base-extensions.json \
  templates/vscode/dotnet-extensions.json > .vscode/extensions.json

# Pre-commit: concatenate with indentation
{
  cat templates/pre-commit/base.yaml
  sed 's/^/  /' templates/pre-commit/dotnet.yaml  # Indent by 2 spaces
} > .pre-commit-config.yaml
```

### Multi-Language Projects

Merge base + all relevant language templates:

```bash
# EditorConfig
cat templates/editorconfig/base.ini \
    templates/editorconfig/typescript.ini \
    templates/editorconfig/shell.ini > .editorconfig

# VSCode Settings (merge multiple languages)
jq -s '.[0] * .[1] * .[2]' \
  templates/vscode/base-settings.json \
  templates/vscode/typescript-settings.json \
  templates/vscode/shell-settings.json > .vscode/settings.json

# VSCode Extensions (merge multiple languages)
jq -s '{recommendations: (.[0].recommendations + .[1].recommendations + .[2].recommendations | unique)}' \
  templates/vscode/base-extensions.json \
  templates/vscode/typescript-extensions.json \
  templates/vscode/shell-extensions.json > .vscode/extensions.json

# Pre-commit (append multiple languages with indentation)
{
  cat templates/pre-commit/base.yaml
  sed 's/^/  /' templates/pre-commit/typescript.yaml
  sed 's/^/  /' templates/pre-commit/shell.yaml
} > .pre-commit-config.yaml
```

### Automated Setup

Use targeted skills for automated template merging:

- `/editorconfig` - Detect languages and merge EditorConfig templates
- `/vscode` - Detect languages and merge VSCode settings/extensions
- `/pre-commit` - Detect languages and merge pre-commit hooks

## Template Categories

### Base Templates

Apply to ALL projects:

- `editorconfig/base.ini` - Common editor rules
- `vscode/base-settings.json` - Format on save, default formatter
- `vscode/base-extensions.json` - EditorConfig, Prettier, Markdownlint
- `pre-commit/base.yaml` - Prettier, Markdownlint, Gitleaks

### Language-Specific Templates

Only include when using that language:

- `dotnet-*` - C#-specific (4-space, CSharpier, StyleCop)
- `typescript-*` - TS/JS-specific (ESLint, tsc type checking)
- `shell-*` - Shell script-specific (shfmt, shellcheck)
