---
name: pr-comment
description: "Use when user says /pr-comment, wants to leave a PR review comment, or asks to draft a comment for a PR. Drafts single inline or PR-level comments using the my-voice skill + PR-specific styleguide patterns, optionally with a suggestion block. Confirms before posting unless --auto-post."
user-invocable: true
argument-hint: '"<description>" [PR#] [file:line] [--auto-post] [--fix-file <path>] [--dry-run]'
---

# pr-comment Skill

Draft and post a single PR review comment (inline or PR-level), applying
the user's voice plus PR-specific styleguide patterns.

## When to invoke

- User says `/pr-comment` with a description of the concern (and
  optionally PR#, file:line)
- User asks "draft a PR comment for X" / "leave a comment on the PR
  about Y"

For PR approvals or request-changes verdicts, this is not the right
skill. Those belong to a future `pr-review` skill (review-submission
shape with body + event type + bundled inline comments).

## Future composition

A planned enhancement will compose this skill from `/review` for per-
finding comment posting, passing `--auto-post` and optionally
`--fix-file`. Not implemented yet.

## Prerequisite: load the styleguide

Load **two files** from the private `voice-samples` repo:

1. `~/repos/voice-samples/styleguide/generic.md` - generic voice rules
2. `~/repos/voice-samples/styleguide/pr-comment.md` - PR-specific
   patterns (review comment structure, scope and depth, suggestion
   blocks)

If either file doesn't exist, the user hasn't cloned the repo. Tell
them to run:

```bash
gh repo clone agilenut/voice-samples ~/repos/voice-samples
```

Do not proceed without both files. Apply generic rules first, then
layer the PR-specific patterns on top.

## Step 1: Parse args and resolve context

Parse positional and flag arguments:

- **Positional 1**: `<description>` of the concern. **Must be quoted**
  if it contains spaces; everything before the first bare integer,
  `file:line` token, or `--flag` is treated as the description.
- **Positional 2 (optional)**: PR number (bare integer)
- **Positional 3 (optional)**: `file:line` or just `file`
- **Flags**: `--auto-post`, `--fix-file <path>`, `--dry-run`

Resolve missing required context interactively (only when not
`--auto-post`):

- **PR number**: if not in args, run
  `gh pr view --json number --jq .number` from the current branch. If
  no open PR for current branch, ask the user.
- **File:line**: if not in args, ask the user. PR-level comments are
  valid without file:line - confirm with the user that they want a
  PR-level comment if they don't supply one.

Capture owner/repo for posting:
`gh repo view --json owner,name --jq '.owner.login + "/" + .name'`.

Head SHA is fetched later at post time (Step 7), not up front, so a
long confirmation dialog doesn't post against a stale commit.

## Step 2: Decide inline vs PR-level + validate line in diff

If file:line is provided, the comment is **inline**. Validate that the
line is in the PR's changed range:

1. Fetch PR files:
   `gh api -X GET repos/<owner>/<repo>/pulls/<n>/files --jq '.[] | {filename, patch}'`
2. Locate the file in the response. If not present → file is not in
   the PR diff.
3. Parse the patch hunks:
   - For comments on added or unchanged lines, check the cited line
     against `@@ -... +new_start,new_count @@` ranges on the new side
     (record `side=RIGHT`).
   - For comments on deleted lines, check against
     `-old_start,old_count` ranges (record `side=LEFT`). Less common
     but valid.
4. If not in any hunk:
   - **Interactive mode** → fall back to PR-level with `file:line`
     embedded in the prose. Surface in confirmation:
     `Line <N> is outside the PR diff - falling back to PR-level comment with file:line in the body.`
   - **--auto-post mode** → do NOT silently degrade. Fail with:
     `ERROR: Line <N> is outside the PR diff. Caller should re-check target or drop --auto-post.`
     Exit non-zero so the caller (e.g. `/review`) can decide.

If no file:line, the comment is **PR-level** - no diff validation
needed.

## Step 3: Decide suggestion block

A suggestion block belongs ONLY when:

- Comment is inline (PR-level can't carry suggestion blocks)
- Fix is localized: same file, few lines, no structural ripple
- AND one of:
  - `--fix-file <path>` was provided (see below)
  - **Interactive mode** (not `--auto-post`) AND the concern translates
    clearly into specific code changes that you can confidently propose
    based on the file context

**Never auto-generate a suggestion when `--auto-post` is set without
`--fix-file`.** Without a human in the loop, the risk of wrong code
silently posting is too high. In that case, prose-only.

**With `--fix-file`**:

1. Read the file verbatim via Read tool.
2. Use its contents as the replacement body of the suggestion block
   (no reformatting, no omissions).
3. Determine the line range the suggestion replaces from the cited
   file:line and the fix-file content size.
4. Wrap in a GitHub suggestion fence (see Step 4 for the shape).

**Without `--fix-file`, in interactive mode**:

1. Use Read to load the file at the cited line range.
2. Determine the line range the suggestion replaces (default: just
   the cited line; expand if the fix needs surrounding lines).
3. Compose the replacement code that addresses the concern.
4. Wrap in a GitHub suggestion fence.

If confidence is low (concern is vague like "this is too verbose"
without specifics), skip the suggestion block. Comment stays
prose-only.

## Step 4: Draft the comment

Apply the `my-voice` skill's process (Step 3 of
`~/.claude/skills/my-voice/SKILL.md`) for generic rules, then
layer the pr-comment styleguide's patterns on top. Key choices driven
by context:

- **Current-state vs future risk** → factual lead vs acknowledgment lead
- **Fix = diagnosis** → action-first; else observation-first
- **Own repo or peer's code** → less hedging vs more; "Have you considered"
  appropriate on peer's code
- **Single concern vs multi-point** → single paragraph vs
  "Two smaller things while we're here" structure
- **Scope and depth** → trace impact through the stack; name downstream
  effects; don't drop substance in the name of brevity
- **Pair related observations** in same comment using "Separate issue
  while we're here:" rather than opening a second thread

Append the suggestion block (if any) after the prose. Wrap the
replacement code in a fenced block with language tag `suggestion`
(opening fence: three backticks followed by `suggestion`; closing
fence: three backticks). GitHub renders this as a one-click accept
UI.

## Step 5: Cut-pass and validate

Run the `my-voice` skill's Step 5 (Cut-pass) and Step 6 (Validate) on the
drafted comment. `my-voice` owns the full checklist; keeping it there avoids
drift when it grows new rules.

## Step 6: Confirm (skip if --auto-post)

Show the user:

```text
Comment ready to post:
  Target: PR #<N>, <file>:<line>  (or "PR-level")
  Includes suggestion block: <yes (N lines) | no>
  [Falling back to PR-level: <reason>]   (only when applicable)

<comment body preview>

post? y/n (or describe revisions)
```

Input parsing - case-insensitive, whitespace-trimmed, and ONLY these
exact tokens count as y/n:

- Affirmatives: `y`, `yes`, `go`, `post`, `ok` → proceed to post
- Negatives: `n`, `no`, `cancel` → exit without posting (no partial
  state)
- Anything else - including an affirmative/negative token followed by
  more content ("y but drop the suggestion") - is treated as revision
  direction, redraft from Step 4 with the new guidance, re-confirm

## Step 7: Post (skip if --dry-run)

**Re-fetch head SHA at post time** to handle commit drift between
draft and post:

```bash
HEAD_SHA=$(gh api -X GET repos/<owner>/<repo>/pulls/<n> --jq .headRefOid)
```

**Re-validate the file:line against the fresh diff** (same procedure as
Step 2) before posting. A push during the confirmation dialog may have
shifted hunks or removed the cited line.

- Interactive mode: surface the change, re-confirm with the user.
- `--auto-post` mode: abort with error (per Step 2 policy).

**Inline comment** - construct the request body with `jq` and send
via `--input -` on stdin. The body contains triple-backtick fences and
may contain quotes, dollar signs, and newlines, which `-f body="..."`
shell-interpolation would mangle:

```bash
jq -n \
  --arg body "$BODY" \
  --arg commit_id "$HEAD_SHA" \
  --arg path "$FILE" \
  --argjson line "$LINE" \
  --arg side "$SIDE" \
  '{body: $body, commit_id: $commit_id, path: $path, line: $line, side: $side}' \
  | gh api -X POST repos/<owner>/<repo>/pulls/<n>/comments --input -
```

- `$SIDE` is `RIGHT` for comments on added/unchanged lines (default),
  `LEFT` for deletions (as determined in Step 2).
- For multi-line inline comments: add `start_line` and `start_side` to
  the jq object (and set `start_side` to match the hunk side).

**PR-level comment** - write body to a scratch file to sidestep shell
escaping entirely:

```bash
printf '%s' "$BODY" > "$TMPFILE"
gh pr comment <n> --body-file "$TMPFILE"
```

Or equivalently via `gh api`:

```bash
jq -n --arg body "$BODY" '{body: $body}' \
  | gh api -X POST repos/<owner>/<repo>/issues/<n>/comments --input -
```

## Step 8: Dry-run mode

When `--dry-run` is set, do NOT execute the post. Instead, print the
full command that would be run and exit. Useful for development and
auto-post sanity checks.

Output format:

```text
DRY RUN - would execute:

<full gh command with substituted values>

Comment body preview:
<body>
```

## Failure modes

- **No open PR for current branch and no PR# in args**: surface
  clearly, ask user for the PR number (interactive) or exit with the
  reason (auto-post).
- **File not found at the cited line**: tell user the file/line is
  invalid, ask for correction.
- **Line outside diff**: see Step 2 - fall back (interactive) or fail
  (auto-post).
- **Network error on post**: surface the gh error verbatim; do not
  retry automatically. User can re-run with the same args.
- **Head SHA drift during confirmation**: Step 7 re-validates and
  catches this before posting.
- **Styleguide missing on this machine**: per the prerequisite step,
  tell user to clone the voice-samples repo. Don't proceed.

## Output

After successful post, print one line:

```text
Posted: <URL of the comment>
```

For inline comments, extract the URL from the API response by piping
through `jq -r .html_url`.
For PR-level comments, `gh pr comment` prints the URL directly.

For `--dry-run`, no post URL - just the dry-run output from Step 8.

## Iteration during confirmation

If the user revises ("drop the suggestion block" / "make it shorter"
/ "use 'tricky bit' instead of 'risk'"), apply the revision and
re-draft from Step 4. Keep iterating until they say an affirmative
or negative from the Step 6 token list.

If the user teaches a new rule via the revision ("never say X" /
"always Y in this case"), suggest an edit to the styleguide after
the comment is posted.
