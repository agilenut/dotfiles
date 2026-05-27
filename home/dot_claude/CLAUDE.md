# Rules

_Cross-cutting rules for collaboration, decisions, and meta-process._

- When I ask a question, just answer it — do not take action unless I ask
- When a constraint drives complexity, verify it still holds before
  building workarounds
- NEVER use inline scripts (`bash -c`, `python -c`, `node -e`, heredocs
  feeding interpreters, here-strings, or any `<lang> -c/-e` form) — use
  Read/Edit/Grep/Glob; if no built-in fits, ask first. Heredocs feeding
  non-interpreter commands are fine (e.g. `git commit -m "$(cat <<EOF ... EOF)"`).
- Ask only when the answer would change what you do next. If you'd take
  the same action either way, decide and state why. If the real
  uncertainty is upstream of the options you're about to list, surface
  that instead.
- If you list options for me, pick one and state the principled reason —
  silent option lists are punting
- Every option must be a path you'd actually take — no hybrids or filler
  invented to fill slots
- Single-keystroke questions (y/n, a/b/c) — I may answer with
  combinations (a+b); keep the a/b/c shape, don't reach for multi-select
  tooling. If there's only one real alternative, ask y/n.
- Treat sibling-repo precedent as one data point, not a directive; when
  flipping a recommendation after seeing precedent, name the new
  principled reason — if the only reason is consistency, surface that as
  a trade-off, not the verdict
- **Match the idiom.** Language/framework idiom > project conventions >
  industry standard > cross-repo precedent. Don't fight the grain.
- **Reject false dichotomies.** Most "A vs B" choices are blends. Lead
  with principles; don't dogmatize.
- **Always include the WHY**, not just the what — for recommendations,
  reviews, and explanations.
- **Make me better.** Push back firmly with reasoning when disagreeing;
  ask clarifying questions when intent is unclear; surface gotchas I may
  not have anticipated; suggest collaboration improvements.

## Bash

_Hook behavior, allow-list peeling, command shapes that prompt vs auto-allow._

- PreToolUse hook splits on `&&`, `||`, `;`, `|`, and newlines and checks
  each segment independently. Pipelines and chains auto-approve when
  every segment is allow-listed — compose freely (e.g.
  `gh pr list --json … | jq …`, `git log --oneline | head`).
- Allow-listed text tools to compose with: jq, grep, sed, head, tail,
  sort, uniq, wc, cut, diff.
- Wrapper commands `time`, `nice`, `env` (binary form), `command`,
  `exec`, `ionice`, `taskset` are peeled — the inner command is what's
  checked. `sudo`/`doas` are not peeled (privilege escalation always
  prompts).
- `xargs [FLAGS] CMD` is peeled — `CMD` is what's checked, with
  positional args attached. `xargs sh -c '…'` / `bash -c` / `python -c`
  / `awk` still prompt (the executor is what's checked). Unknown long
  flags bail rather than mis-parse.
- `awk '…'` auto-allows when the program scans clean — no `system(`,
  `getline`, `print >`/`print |`, `printf >`/`printf |`, `@load`,
  `@include`, or backticks. Programs using `-f`/`-i`/`-e`/`-E`/`--source`/`--include`
  (loads external scripts, in-place rewrite) always prompt. Tokens that
  look dangerous as string-literal substrings get rejected as a
  false-positive — accepted cost.
- Prefer `jq` for structured data (JSON, NDJSON) and `grep -E` for
  line / text filtering. Reach for `awk` only when neither fits or the
  user explicitly asks — it occasionally false-positive-prompts under
  the safety check above, and jq/grep read more naturally.
- Forms that still always prompt: `sh -c '…'`, `bash -c '…'`,
  `python -c '…'`/`python -m …`, `node -e '…'`, heredocs feeding an
  interpreter, here-strings. The _executor_ is what's checked, not the
  heredoc/string.
- Native ASK overrides hook-allow. If an all-allow-listed chain still
  prompts, check `~/.claude/settings.json` `ask` for a broader pattern
  catching one segment.
- Debug with `SMART_APPROVE_VERBOSE=1` — appends per-segment match info
  to `~/.claude/logs/smart_approve.log`. `tail`/`grep` it to see which
  segment didn't match. Note: command previews land in the log
  unredacted, so don't enable while running commands with secrets in args.
- `gh api` reads — place `-X GET` (or `--method GET`) IMMEDIATELY
  after `gh api`, before the path. Other placements prompt:
  - do: `gh api -X GET repos/x/y/pulls/1`
  - don't: `gh api repos/x/y/pulls/1 -X GET` (strict matcher needs a
    trailing arg after `-X GET`; usually missing)
  - don't: `gh api repos/x/y/pulls/1` (no method declared)
- Quiet flags only on builds/tests where success is the only signal:
  `dotnet build -v quiet`, `dotnet test -v quiet`, `npm run --silent`.
  Failures still surface errors. Default verbosity while iterating.
- Don't pre-truncate exploratory output with `head -n 5` / `tail -n 20`
  — too-small first window forces a re-run, paying twice. Read full
  output once; truncate once you know the shape.
- No global installs: `npx` for one-off commands, `pip` only inside a
  venv, `pipx` for CLI tools, `npm install` only in a project (never
  `-g`), `dotnet tool` use `--local` in projects or `--global` only
  outside a project

## Planning

_How to scope, sequence, and pause work for non-trivial tasks._

- Break work into small, independently committable steps — one commit
  per step
- If you'd diverge from the plan's scope or approach, stop and ask
  before acting. Tactical choices inside the plan don't need an ask —
  update the plan file as the choice is made (in the same commit as
  code if the plan is tracked; just save if gitignored)
- NEVER write out full plan content in chat — use Edit for targeted
  changes, then summarize what changed
- When the user signals new work (story / issue / "let's build X"),
  invoke `/plan` to scope it; tangents mid-implementation stay tangents
  unless explicitly escalated
- Plan Commits row tags drive review cadence: `review: per-commit`
  forces `/review` before each commit. `end-of-PR` runs once before
  pushing (typically before `gh pr create`).

### Plan Naming

- Format: `{YYYY-MM-DD}-{brief-description}.md`
- Never include story numbers in filenames
- Never use auto-generated or random filenames

### Plan Frontmatter

```yaml
---
work: "<work-stream-name>"
branch: "<branch-name-or-null>"
stories: [82, 86]
worktree: false
---
```

## Workflow

_Boy-scouting, atomic PRs, backward compat, "done" ladder, under pressure._

- **Boy-scout** unrelated debt in files you touch, same commit, unless
  very large/widespread (then follow-up commit or PR after — almost
  never a separate PR unless review burden becomes extreme)
- **Refactor sequencing.** Predictable refactor: refactor first, then
  feature. Discovered refactor: judgment call.
- **Atomic PRs.** Code + tests + docs together; clear single intent.
  Reduce forward-looking work.
- **Tech debt.** Boy-scout first. TODO comments only short-term during
  PR or for genuine forward-looking notes. GitHub issues sparingly, for
  real gaps.
- **Backward compat.** Aggressive delete when controlling all sides. DB
  migrations split for no-downtime if real users; drop fast otherwise.
  APIs: get it right initially, expand carefully when users exist,
  version only as last resort with external clients.
- **Feature flags.** Prefer none; temporary use only for risky or
  hard-to-rollback changes.
- **Lint / format.** Strict in pre-commit AND CI for every language
  (md/yaml/json included). Prefer editorconfig + embedded rules
  (e.g. .NET naming).
- **CI.** Thoroughness over speed.

### "Done" ladder

| Stage   | Bar                                                                                       |
| ------- | ----------------------------------------------------------------------------------------- |
| Commit  | code + tests + docs + pre-commit + review if non-trivial + local tests + manual if needed |
| Merge   | CI green + security scans + dependency audits                                             |
| Promote | main CI + staging tested                                                                  |
| Done    | in prod; verify if needed                                                                 |

### Under pressure

- **Cut order.** Push deadline > trim polish > cut test edges > cut
  refactoring (last resort).
- **Ambiguous requirements.** Ask requester if available; small
  assumptions to keep moving if not. Plans only for large, hard-to-undo
  work.
- **Hard problems.** Identify knowns vs unknowns; validate assumptions;
  test hypotheses to build/validate the mental model. For code: failing
  test in clean branch, iterate safely, refine.

## Architecture

_VSA + DDD + Onion; modular monolith first; types carry validation._

- **VSA + DDD + Onion blend.** Vertical slices per feature; factor
  external deps to infrastructure; shared utilities in core;
  repositories in core/infra split only when real DRY need spans slices.
- **Modular monolith first.** Separate teams or distinct scaling needs
  justify pre-splitting (Conway's law). Default to clean FE/BE process
  separation.
- **Domain depth.** Anemic for CRUD, rich for non-trivial logic.
- **Types carry validation when possible** (illegal states
  unrepresentable). Validate at API boundary; UI validation for UX
  speed; guard clauses on public class methods when types can't carry it.
- **Composition over inheritance** when other things equal; don't fight
  framework expectations.
- **Immutable-leaning** where it doesn't complicate structure.
- **12-factor / env-var config** where the platform supports it.
- **DI / DB access / async**: framework idiomatic. ORM by default with
  raw SQL when needed; ORM directly in slices, repository wrap when
  shared queries appear.

## Code

_Library use, warnings, secrets, DRY, naming, comments, perf, build vs buy._

- ALWAYS look up current APIs and versions on Context7 before using a
  library; use web search for broader approach questions
- NEVER suppress compiler warnings or analyzer rules without asking first
- No committed secrets or credentials
- **DRY**: naturally eager, especially when reuse looks likely or aids
  testability. Watch for false-DRY — VSA features that look similar but
  are conceptually distinct stay split.
- **Strict types** everywhere unless compelling code-reduction with low
  risk.
- **Naming**: high care. Match domain language + industry + project
  conventions. Clarity non-negotiable.
- **Comments**: well-named code first; sparse inline comments for
  non-obvious WHY. Still fill XML doc on public .NET API surface for
  tooling integration. Comments add value on top of naming, not as a
  substitute.
- **Function size**: balance size vs count. Named functions clarify
  when reused. Don't fragment for line count alone. Splits motivated by
  testability often signal a missing object, not just a method.
- **Performance**: clear code first; handle obvious traps (N+1, hot
  loops) cleanly; profile before further optimization.
- **Build vs buy**: write inline if ~20 lines and no dominant lib.
  Otherwise prefer well-supported, actively maintained, good-DX deps.

## Errors

_Fail fast, light threat modeling, validate at borders._

- **Fail fast and loud.** Throw freely; handle at borders; structured
  logging on errors and protocol boundaries (HTTP, DB).
- **Pre-action `if` checks** to avoid known pitfalls.
- **Don't over-instrument**; iterate logs/metrics based on prod needs.
- **Security**: threat-model lightly up front; validate at boundaries;
  lean on framework defaults; defense in depth where pragmatic. These
  compound, not compete.

## Dotnet

_File-per-type convention._

- Prefer 1 type per file unless they really go together (e.g. static
  LoggerMessages)

## Git

_Branching, committing, PRs, post-merge cleanup._

- Never work on main — create a feature branch first
- Never commit/push/merge/amend/force-push unless asked
- When the user signals PR-lifecycle work (creating, merging, "is CI
  done", "open the PR", bare "pr"), invoke `/pr` first — don't run
  free-form `gh pr create` / `gh pr merge` / `gh pr checks` ahead of
  it.
- Before committing: stage files, then run the repo's pre-commit
  framework if one is configured, re-staging until clean. Detect by
  marker (first match wins):

  - `.pre-commit-config.yaml` → `pre-commit run`
  - `lefthook.yml` / `.lefthook.yml` → `lefthook run pre-commit`
  - `.husky/pre-commit` → `npx lint-staged` if `package.json` has a
    `lint-staged` field, else let `git commit` fire it natively
  - `.lintstagedrc.*` or `package.json` `lint-staged` field
    (without `.husky/`) → `npx lint-staged`
  - No marker → skip; `git commit` fires any native hooks in
    `.git/hooks/`

  If the detected runner isn't installed (`command -v <runner>` fails),
  surface that and ask before falling back to native hooks — the user
  may want to install the runner first.

- Before committing, consider if a review is warranted. If a plan
  governs the work, follow its review tag. Otherwise, run `/review`
  for non-trivial changes (new behavior, multi-file refactors); skip
  for truly trivial (typo, dep bump, comment edit).
- Each commit must build, test, and pass independently, no dead code or
  forward refs
- Commit message: title ≤70 chars, imperative summary. Body: 1-3
  short sentences explaining the why + a brief bullet list of the
  meaningful changes if it helps. Target ~10-20 lines total. Don't
  enumerate files, don't recap the diff, don't add section headers
  like "Backend:" / "Frontend:" unless the change genuinely spans
  layers in non-obvious ways.
- NEVER add Co-Authored-By lines to commits
- NEVER add "Generated with Claude Code" to PRs
- Issue references: default to "Part of #N" (keeps issue open for
  board review). Use "Closes #N" / "Fixes #N" only when explicitly
  asked.
- Only reference an issue when the number is known — from the plan's
  `stories:` frontmatter, branch name (e.g. `feat/123-foo`), commits,
  or the user. Don't fabricate; ask which issue if the convention
  seems to require one.
- Before opening a new tracking issue for related work, check for an
  existing open issue covering the broader initiative — reuse with
  "Part of #N" instead. Issues stay open across multiple related PRs.
- Post merge CI failure: comment on failed PR (what broke, fix PR link)
  and update the issue with a running failure log

## Worktree

_Entering, exiting, where they land._

- `ToolSearch select:EnterWorktree` then call `EnterWorktree` — harness
  updates cwd; don't `cd` or `git -C` to navigate
- `ExitWorktree` triggers cleanup (docker compose down + worktree remove)
- Worktrees land at `<parent>/<repo>--<branch-slug>` (sibling).
  Auto-managed by `~/.claude/hooks/{create,remove}-worktree.sh`

## Workspace

_Where plans and reviews live; resolution order for plans directory._

### Plans Directory Resolution

1. `plansDirectory` from `.claude/settings.local.json`, then
   `.claude/settings.json`
2. If not found and in a worktree: main tree's
   `.claude/settings.local.json`, then `.claude/settings.json`
3. If not found: `~/.claude/settings.json`
4. If found at any step, resolve relative to main worktree's project
   root (or project root if not in a worktree)
5. If not found and in a repo, check for `.plans/` at main worktree root
   — use if it exists
6. If not found, use `.claude/plans` at main worktree root
7. If not in a repo, use `~/.claude/plans`

### Reviews Directory

All review output goes to `.reviews/` relative to main worktree's
project root: `.reviews/code/` for code reviews, `.reviews/plans/` for
plan reviews. Branch review state is tracked in
`.reviews/code/.last-reviewed.json`.

## Database

_Migration safety._

- EF migrations must be backward-compatible — never rename or drop
  columns in one step; use expand/contract

## Testing

_TDD, AAA, build/test before reporting completion._

- TDD: write test first, run it, see it FAIL, then write minimum code
  to pass, run again
- Arrange / Act / Assert comments
- Always build and test changes before reporting completion
- If a required tool is unavailable (e.g., Docker), fix or ask — don't
  skip
- NEVER change a test just to make it pass — if a test breaks, fix the
  code or ask me
- If a test fails because required inputs are missing (fixtures,
  reference data, golden samples), create the inputs — don't make the
  test skip-on-empty. Skip-on-empty pretends the test passes when it
  actually didn't run.
- **~90% coverage target** excluding tests themselves; behavior matters
  more than %; diminishing ROI accepted at edges. Complex logic always
  tested.
- **Pyramid believer.** VSA reduces unit-test reuse — integration tests
  give high confidence when DB/HTTP involved (must stay fast). E2E
  essential for user-facing flows. Logic-bearing units (not prop
  getters) get unit tests.
- **Mocks**: layer-dependent — heavy at unit, real deps at integration,
  nothing mocked at E2E.

## Language

_How to write, in chat and in docs._

- **Clarity is king.** A reader should grasp your meaning on first read.
  Simple words, simple sentences, direct phrasing.
- **Use plain language; avoid unnecessary jargon.** Pick the plain word
  over the insider term. Insider labels are fast to write, slow to read.
- **Coin terms deliberately.** Don't turn a repeated phrase into a label
  (`ask in chat`, not `chat-ask`). Coining is fine when deliberate and
  reused — glossary, API surface, ubiquitous language.
- **Use structure deliberately.** Bullets for discrete items, prose for
  flow. Prefer markdown pipe tables for multi-dimensional comparisons;
  avoid ASCII hyphen-art tables (render poorly). Parallel construction;
  paragraph breaks where ideas shift. One decision at a time when
  presenting many.
- **Match context to the reader.** Give them what they need to decide.
  Don't overwhelm; don't skip the critical bits.
- **Be concise — but not at the cost of clarity.** Full sentences read
  naturally; don't drop articles ("a", "an") to save characters.
  Parentheticals and examples earn their place.

## Documentation

_How to write prose: principles for READMEs, project docs, and context
files (CLAUDE.md, MEMORY.md, skills, agents)._

Universal:

- **Ask first, write second.** Before adding any content (new section,
  new bullet, new paragraph), ask: does the reader need this? Is this
  the right context for it? If either is unclear, don't add it. Default
  toward restraint.
- Capture only meaningful signal; no fluff, no restatement, no "as
  discussed above"
- Use specific identifiers (class / function / file / table / command
  names) deliberately. Include them when they're the content (setup
  commands, API reference) or genuinely help the reader; skip them when
  they're noise distracting from the core message.
- Structure (bullets, headings, spacing) matters more than character
  count
- Lists for discrete items; prose for flowing ideas
- One-line italic TL;DR after each top-level section heading
- Wrap prose paragraphs at ~80 chars; leave one-line bullets, tables,
  and code blocks alone
- Cross-references add cognitive load — avoid forward/backward refs
  when possible

Project docs (READMEs, guides, design docs):

- Document the system as a reader needs it now, NOT as a changelog of
  what changed. Don't add a new section unless readers benefit from a
  dedicated landing place.
- When adding a new way to do something, audit and remove or merge the
  obsolete ways. Replace, don't append.
- Update docs in the same commit as the code change — never separately.
- EXCEPTION: append-only-by-design docs (ADRs, CHANGELOG.md, decision
  logs) preserve history — don't overwrite previous entries.

Context files (CLAUDE.md, MEMORY.md, skills, agents):

- Only add or suggest rules/memory/config that genuinely change behavior
  — if it won't change what Claude does, don't propose it.

Project doc structure (when starting / auditing a repo):

- `README.md` at top for product / getting-started; `docs/` for
  everything else
- `docs/decisions/` for ADRs
- `architecture.md` (single file if simple, separate component `.md`
  files if complex; diagrams help)
- `design.md` for UI; `database.md` for ERD / mermaid when needed
- `docs/runbooks/` for ops processes
- `CLAUDE.md` references important docs, gotchas, tools — often
  gitignored on client projects
- Plans usually not checked in
