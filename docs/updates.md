# Updates (macOS)

_What the daily update job runs, where its output goes, and what each kind
of status item means._

## What runs

_`update` runs everything by hand; the daily job skips what can ask for a
password or what you'd want to watch._

`update` runs [topgrade](https://github.com/topgrade-rs/topgrade) with
`~/.config/topgrade.toml`: Homebrew formulae and casks, the App Store, mise,
uv tools, npm, .NET tools, VS Code extensions, Claude Code, compose images,
and macOS updates. topgrade runs every step it finds a tool for; the config
turns off the steps it shouldn't run and replaces two of them with the drift
and image commands below.

The `dotfiles.topgrade` launchd job runs `topgrade-daily` once a day from
05:00 (on wake if the Mac was asleep). It skips the steps that can ask for a
password (macOS updates, the App Store, casks other than Claude Code) and
the plugin updates for zsh, tmux, and nvim, which `update` runs with the
output in view.

## Logs

_One log per run, plus one for the job itself._

- `~/Library/Logs/topgrade-daily-<day>.log` - each run's output.
- `~/Library/Logs/topgrade-daily.err.log` - the job's own messages, such as
  why an hour was skipped.

## Failures

_A failure turns the tmux marker red until a run succeeds._

A run fails when a step fails, the run times out after 2 hours, or
topgrade's config doesn't load (the run then stops before upgrading
anything). A banner names the steps. The next day's run tries again, and a
clean `update` clears the failure. Every `update` also refreshes the list
of casks waiting for it.

## Dotfiles drift

_A managed file changed on this machine that also differs from the
dotfiles source._

A templated file's change is copied into its `.tmpl` by hand. JSON is compared after normalizing, so an
app reformatting its own config doesn't count. `mise use -g` edits
`~/.config/mise/config.toml`, so it shows up as drift until the change goes
into the source.

## Images

_The job pulls new images for compose projects that have containers, never
ones a project builds._

It can't see an image built with a plain `docker build -t`, or by a project
whose containers are gone (`docker compose down`) or whose compose file is
gone (a removed worktree). Another project that uses one of those images
gets it pulled from the registry.

Pinned tags and Dockerfile base images belong to each repo and aren't
changed here.
