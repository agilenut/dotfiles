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
05:00, on the first hourly check while the Mac is fully awake. While the Mac
sleeps (lid closed, or idle), it waits for someone to wake it: a sleeping Mac
wakes itself only for a few seconds at a time, too briefly for a run. During
a run, the Mac won't idle-sleep, for up to 2.5 hours. It skips the steps that
can ask for a password (macOS updates, the App Store, casks other than Claude Code) and
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

A pulled image reaches a running container only when the container is
recreated. The status lists running containers still on an older pulled
image. One on an older build of an image a project builds is left out, since
that project's own build picks it up.

`update-containers` shows the compose command for each listed project,
asks, and runs them. It uses the project name, config files, and
`--env-file` files recorded on the container. Plain
`docker compose up -d` in the folder can target a different project, and
passes none of those env files.
Variables a script exported when it started the project aren't recorded, so
they are lost here; have the script pass an env file instead, or recreate
the project the way it was started.

`update-containers` skips any container whose published ports would change
and names the old and new ports, since the new ports may belong to another
project and the replacement would then fail to start after the old container
is removed. Lost variables are the usual cause. It also skips a project
whose config or env file is gone, a container whose config compose can't
read, and one whose service is no longer in its config. Each of these skips
fails the run.

Pinned tags and Dockerfile base images belong to each repo and aren't
changed here.
