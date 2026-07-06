# Linting & Formatting Tool Preferences

_Opinionated defaults for lint / format / type-check tooling per language. Use the
**Primary** choice for new work; **Bridge/legacy** tools are still supported
(config-gated) in existing repos until migrated._

## Principles

_Config as data in the repo; behavior in the editor._

- **Tool-native config files over editor settings.** Put rules/scope in
  `pyrightconfig.json`, `eslint.config.js`, `stylelint.config.js`,
  `tsconfig.json`, `.editorconfig` — read by every editor + CLI + CI. Pull keys
  OUT of `.vscode/settings.json` wherever a tool-native home exists.
- **Opt-in by artifact.** Opinionated tools (eslint, stylelint, ruff, black,
  mypy) activate only where the project declares them (config present). Universal
  tools (stylua, shfmt, editorconfig) are always on. Test: "run with defaults in a
  project that doesn't use it — does it fight the project?" Yes → opt-in.
- **Prefer project-local binaries** (`node_modules/.bin`, `vendor/bin`, `.venv`)
  over global installs, so each repo runs its pinned tool version.
- **Editor follows the config.** Once a repo's config declares a tool, nvim /
  VS Code / CI agree automatically. Migrating a repo = editing its config, not the
  editor.

## Matrix

| Tech                | Format                       | Lint                               | Type-check       | Notes                                                                                            |
| ------------------- | ---------------------------- | ---------------------------------- | ---------------- | ------------------------------------------------------------------------------------------------ |
| **Python**          | ruff format                  | ruff check                         | basedpyright     | ruff replaces black + isort + flake8 + pyupgrade + most pylint. mypy only for plugin ecosystems. |
| **TypeScript / JS** | prettier                     | eslint (flat)                      | tsc (LSP: vtsls) | Biome = future consolidation for non-Vue repos.                                                  |
| **Vue**             | prettier                     | eslint (+ vue plugin)              | vue-tsc / vue_ls | Biome can't parse `.vue` — stay on eslint.                                                       |
| **React / Next**    | prettier (+ tailwind plugin) | eslint (flat)                      | tsc              | Biome candidate later; keep prettier for `prettier-plugin-tailwindcss` class sort.               |
| **CSS / SCSS**      | prettier                     | stylelint                          | —                | cssls for completion/hover with linting OFF; stylelint is the linter.                            |
| **C#**              | dotnet format                | Roslyn analyzers (`.editorconfig`) | roslyn LSP       | dotnet format reads `.editorconfig`; csharpier is the alternative.                               |
| **PHP (Laravel)**   | Pint                         | intelephense + larastan/phpstan    | intelephense LSP | Add larastan for real static analysis (Laravel-aware).                                           |
| **Bicep**           | bicep LSP                    | bicep lint                         | bicep LSP        | Self-attaches on `.bicep`.                                                                       |
| **Shell (bash/sh)** | shfmt                        | shellcheck                         | —                | zsh: shfmt only; shellcheck skips zsh — use `zsh -n` for syntax.                                 |
| **Lua**             | stylua                       | lua_ls diagnostics                 | lua_ls           | selene/luacheck optional for deeper lint.                                                        |
| **TOML**            | taplo                        | taplo                              | taplo LSP        | —                                                                                                |
| **YAML**            | prettier                     | yamlls (LSP)                       | yamlls           | Workflows: actionlint (path-scope `.github/workflows/`). yamllint = skip.                        |
| **JSON**            | prettier                     | jsonls (schema)                    | jsonls           | —                                                                                                |
| **Markdown**        | prettier                     | markdownlint-cli2                  | —                | marksman for navigation.                                                                         |
| **GitHub Actions**  | —                            | actionlint                         | —                | —                                                                                                |
| **Commit messages** | —                            | commitlint                         | —                | Conventional Commits, where adopted.                                                             |

## Verdicts / why

_The conflicting-tool calls, with reasoning._

- **ruff over black + isort + flake8 + pylint** — one Rust tool, `ruff format` is
  a Black-compatible drop-in, `ruff check` subsumes isort + flake8 + pyupgrade +
  most pylint. Fast, one config. Note: ruff does **not** type-check.
- **basedpyright over mypy** (primary type checker) — best editor DX (real-time
  LSP), runs in CI as a CLI. Keep **mypy** only where a repo needs mypy-specific
  plugins (django-stubs, SQLAlchemy, pydantic-v1). Rust type checkers are
  maturing (Meta **Pyrefly** hit 1.0 May 2026; Astral **ty** still beta, now under
  OpenAI) — watch, don't switch yet.
- **stylelint + cssls compose** (not either/or) — cssls gives completion/hover
  plus a weak built-in validator that mis-flags Tailwind `@apply`; turn its
  linting OFF and let stylelint (the real, configurable linter) own diagnostics.
  Same shape as tsserver + eslint.
- **dotnet format over csharpier** — reads `.editorconfig` (single source of C#
  style), matches typical .NET CI. csharpier is a fine alternative if a repo
  commits to it.
- **eslint flat config + prettier** is the standard for JS/TS/Vue. Prefer flat
  (`eslint.config.js`) over legacy `.eslintrc`.
- **Biome** — one Rust tool for JS/TS/CSS format + lint, ~10-25x faster, single
  config. Blocker: no `.vue` SFC support (as of v2.3, 2026). Revisit for non-Vue
  React/TS repos; not for Vue codebases.

## Migration direction

- Standardize new/controlled repos on the **Primary** column.
- Legacy bridges (black, isort, mypy) stay wired in the editor but
  config-gated — they fire only where a repo still declares them. pylint is
  not bridged: ruff's `PL` rules cover it; enable those in the repo's ruff
  config instead. C# saves format via the roslyn LSP (same engine and
  `.editorconfig` as `dotnet format`, which stays at pre-commit/CI — it
  loads the whole solution per run, too slow per-save).
- When migrating a repo, edit its tool config (e.g. swap `[tool.black]` →
  `[tool.ruff]` in `pyproject.toml`); the editor follows with no config change.

## Sources (2026)

- [Ruff FAQ](https://docs.astral.sh/ruff/faq/) — ruff format is Black-compatible;
  replaces isort/flake8/pyupgrade/most pylint; no type inference.
- [Ruff alternatives 2026 (BSWEN)](https://docs.bswen.com/blog/2026-03-20-ruff-python-linter-alternatives/)
  — Python type-checker landscape (mypy, pyright, ty beta, Pyrefly 1.0).
- [Biome migration guide 2026](https://dev.to/pockit_tools/biome-the-eslint-and-prettier-killer-complete-migration-guide-for-2026-27m)
  and [ESLint vs Biome 2026](https://reintech.io/blog/eslint-vs-biome-javascript-linting-comparison-2026)
  — Biome maturity + no Vue SFC support.
