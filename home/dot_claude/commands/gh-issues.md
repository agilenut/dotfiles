---
title: GitHub Issues from Sources
description: Create GitHub issues from TODOs, files, folders, or inline descriptions
allowed-tools: Bash(gh:*), Bash(git:*), Read, Glob, Grep, AskUserQuestion, Task(Explore)
argument-hint: '[--todos] [--code-review] [--suggest-features] [path/to/file.md] [path/to/folder/] ["inline description"]'
---

Create GitHub issues from multiple sources and add them to a project board.

## Arguments

$ARGUMENTS

Sources are **additive** - combine multiple in one invocation:

```bash
/gh-issues                                    # Interactive - asks for sources
/gh-issues --todos                            # Parse TODO/FIXME/HACK/XXX from code
/gh-issues --code-review                      # Find bugs, tech debt, security issues
/gh-issues --suggest-features                 # Suggest new capabilities
/gh-issues docs/plans/                        # Parse all .md files in folder
/gh-issues docs/features.md                   # Parse single file
/gh-issues "Add CI/CD pipeline"               # Create from inline description
/gh-issues --todos docs/plans/                # Combine multiple sources
/gh-issues --code-review --todos              # Combine code review and TODOs
```

## Workflow

### Phase 1: Repository Setup

#### 1.1 Detect Repository and Board

```bash
git remote get-url origin
gh project list --owner @me --format json
```

If multiple boards exist, ask which to use. If none, suggest running `/gh-board` first.

#### 1.2 Detect Issue Templates and Types

```bash
ls .github/ISSUE_TEMPLATE/*.md 2>/dev/null
```

Parse template filenames to extract valid issue types:

- `bug.md` → type: `bug`
- `feature.md` → type: `feature`
- `task.md` → type: `task`

**If no templates exist:**

- Ask: "No issue templates found. Would you like to create them first?"
- Options:
  1. "Yes - run /gh-issue-templates to create bug/feature/task templates"
  2. "No - continue without types (issues will have no type field)"

**Read each template file** to extract structure for body formatting.

Parse each template to identify sections (## headings). Store the structure for each type.

Example structures (may differ per repo):

- **bug.md**: Description, Steps to Reproduce, Environment, Additional Context
- **feature.md**: Description, Acceptance Criteria (checklist), Additional Context
- **task.md**: Description, Checklist

**Store valid types and actual template structures** for later use in issue assignment and body formatting.

#### 1.3 Fetch Existing Labels

```bash
gh label list --json name,description,color
```

**Store existing labels** for reuse. Default to using existing labels instead of creating new ones.

### Phase 2: Determine Input Sources

**If arguments provided:** Use the specified sources directly:

- `--todos`: Parse TODO/FIXME/HACK/XXX from code
- `--code-review`: Analyze codebase for bugs, tech debt, security issues
- `--suggest-features`: Suggest new capabilities based on codebase
- `path/to/folder/`: Parse all .md files in folder
- `path/to/file.md`: Parse single markdown file
- `"inline text"`: Create issue from inline description

Skip to Phase 3.

**If no arguments provided:** Ask user for sources interactively. This happens BEFORE label suggestion so we can analyze both repo structure AND actual issue content together.

```text
What sources should I use? (select multiple)
1. Code TODOs/FIXMEs
2. Markdown files in a folder (specify path)
3. Single markdown file (specify path)
4. Inline descriptions (you'll provide text)
5. Code review (find bugs, tech debt, security issues)
6. Feature suggestions (suggest new capabilities)
```

### Phase 3: Parse Input Sources

Parse the selected sources into draft issues. Don't assign labels yet - that happens in Phase 4 after we analyze issues in context.

#### `--todos`: Parse code comments

Scan all code and configuration files for TODO/FIXME/HACK/XXX comments:

```bash
# Use ripgrep to scan all text files, excluding common non-code directories
rg --type-not binary \
   -n 'TODO|FIXME|HACK|XXX' \
   --glob '!.git/**' \
   --glob '!node_modules/**' \
   --glob '!vendor/**' \
   --glob '!.venv/**' \
   --glob '!__pycache__/**' \
   --glob '!*.min.js' \
   --glob '!*.min.css' \
   . 2>/dev/null
```

**Fallback if `rg` not available:**

```bash
grep -rn 'TODO\|FIXME\|HACK\|XXX' \
  --exclude-dir='.git' \
  --exclude-dir='node_modules' \
  --exclude-dir='vendor' \
  --exclude-dir='.venv' \
  --exclude-dir='__pycache__' \
  --exclude='*.min.js' \
  --exclude='*.min.css' \
  . 2>/dev/null
```

For each match:

- Extract file path, line number, comment text
- Create issue title from comment (strip TODO/FIXME prefix)
- Body: Link to `file:line` with context
- Source: `TODO in {file}:{line}`

#### Folder path: Parse markdown files

```bash
find {folder} -name '*.md' -type f
```

For each file:

- Title: First `# heading` or filename (without .md)
- Body: File content (full text if < 2000 chars, else summary)
- Source: `{file}`

#### Single file: Parse markdown

- Parse structured format (headings, bullets, checklists)
- OR treat as single issue if unstructured
- Source: `{file}`

#### Inline text: Create from description

Parse user-provided descriptions into issue title/body.
Source: `Inline description`

#### `--code-review`: Find bugs and tech debt

Use Task(Explore) agent:

```text
Analyze this repository to identify improvements across:
1. Security: Validation, error handling, unsafe operations
2. Maintainability: Duplication, complexity, documentation gaps
3. Cross-platform: Inconsistencies between macOS/Linux
4. Functionality: Missing features, incomplete implementations
5. Testing: Coverage gaps, missing tests

For each finding:
- Describe the issue clearly
- Identify affected files
- Suggest priority (critical/high/medium/low)
- Recommend if it should be split into multiple issues

Provide specific file references with line numbers.
```

Parse agent output into structured issues.
Source: `Code review`

#### `--suggest-features`: Suggest new capabilities

Use Task(Explore) agent:

```text
Analyze this repository to suggest valuable new features the author may not have considered.

Approach:
1. **Understand the codebase**:
   - Read documentation (README, docs/, comments)
   - Examine code structure and existing features
   - Identify the domain/purpose of the project
   - Note existing patterns and architecture

2. **Identify gaps and opportunities**:
   - Common patterns in this domain that are missing
   - Natural extensions of existing features
   - Integration opportunities with complementary tools
   - User experience improvements
   - Developer experience enhancements

3. **Suggest features**, not fixes:
   - Focus on NEW capabilities, not bug fixes or refactoring
   - Think about what would make this project more useful
   - Consider both user-facing and developer-facing features
   - Be creative but practical

For each suggestion:
- Feature name (clear, concise)
- Why it would be valuable (benefit to users/developers)
- How it fits with existing features (natural extension or new capability)
- Implementation complexity estimate (small/medium/large)
- Priority suggestion (would-be-nice / valuable / game-changer)

Examples of good suggestions:
- "Add export to PDF" (for a note-taking app)
- "Support plugins via hooks" (for a CLI tool)
- "Add real-time collaboration" (for a document editor)
- "Support multiple profiles" (for a configuration tool)

Examples of what NOT to suggest (these belong in improvements analysis):
- "Add error handling to X function" (bug fix)
- "Refactor duplicated code" (tech debt)
- "Add tests for Y" (testing gap)
```

Parse agent output into feature suggestions.
Source: `Feature suggestions`

### Phase 4: Suggest Labels Based on Repo and Issues

Now that we have both the repository structure AND the actual issues, suggest labels that cover both.

**IMPORTANT:** Labels should represent functional domains/areas of the codebase, NOT priority, urgency, or types.

**Analyze in combination:**

1. **Repository structure** (from Phase 1):

   - Directory structure and how code is organized
   - Technology stack (languages, frameworks, platforms)
   - Platform-specific concerns (if applicable)

2. **Actual issue content** (from Phase 3):

   - File paths mentioned in issues
   - Topics and domains covered by issues
   - Patterns across issues (many security issues? testing gaps? specific subsystems?)

3. **Existing labels** (from Phase 1.3):
   - **Default to reusing existing labels** whenever possible
   - Only suggest NEW labels if existing ones don't adequately cover the domains

**Use Task(Explore) agent to analyze both together:**

```text
Analyze this repository AND the following issues to suggest domain-based labels.

EXISTING LABELS (prefer reusing these):
[List existing labels with descriptions]

PARSED ISSUES SUMMARY:
[List issue titles and which files they reference]

Labels should represent how someone would mentally model this repository's concerns:
- **Functional domains**: Major feature areas, business capabilities, or subsystems
- **Technical domains**: Technology stacks, frameworks, or architectural layers
- **Organizational concerns**: Cross-cutting aspects like security, testing, documentation

Guidelines:
- Repository should have 5-15 labels TOTAL (for the entire repo)
- Each issue will get 1 label (occasionally 2 if clearly spans domains)
- Prefer single-word labels (e.g., "shell", "packages", "macos")
- Use lowercase with hyphens only when needed (e.g., "cross-platform")
- Think like domain aggregates, not fine-grained components
- **Strongly prefer existing labels** - only suggest NEW labels if truly needed

For each suggested NEW label:
- Name (lowercase, hyphenated only if needed)
- Description (brief, explains what issues with this label relate to)
- Reasoning (why existing labels don't cover this domain)
- Count (estimate how many issues would use this label)
```

**Present labels for review (but DON'T create yet):**

Show existing labels that will be reused plus any suggested new labels. User can see which issues will get which labels during Phase 7 (Interactive Review).

```text
Labels for this batch of issues:

EXISTING (will reuse):
- shell: Shell configuration and scripting
- packages: Package management and installation
- macos: macOS-specific features

SUGGESTED NEW:
1. tests: Automated testing and test infrastructure
   (Reason: 8 issues relate to testing, no existing test label)
2. profiles: Dotfiles profile configuration
   (Reason: 5 issues about profile system, distinct from packages)

Review:
- (a)pprove - Use these labels
- (e)dit {number} - Edit label name/description (e.g., "e 1")
- (r)emove {number} - Remove suggested label (e.g., "r 2")
- (n)ew - Add another label
```

Allow iterative refinement. Store approved label suggestions but **DON'T create them yet** - they'll be created in Phase 8 after issue review.

### Phase 5: Assign Types and Labels

For each parsed issue:

#### 5.1 Assign Type

Use the valid types discovered in Phase 1.2 (extracted from template filenames).

**If templates exist:** Assign type based on issue content and template name patterns:

- Analyze issue description and source
- Match to the most appropriate template type
- Common patterns (if these templates exist):
  - Something isn't working, validation missing, errors → often maps to "bug" type
  - New functionality, new capability → often maps to "feature" or "enhancement" type
  - Refactoring, cleanup, documentation, improvements → often maps to "task" type
- Use judgment based on actual template names in the repo

**If no templates:** Skip type assignment.

#### 5.2 Assign Labels

For each issue, assign **1 label** from the approved label list (Phase 4). Occasionally assign **2 labels** if issue clearly spans multiple domains.

**Typical pattern**: 1 functional or technical domain label

**Optional second label** (use sparingly): Add a second label only when issue clearly involves both a functional domain AND a technical/organizational concern

Examples:

- `shell` (typical - single domain)
- `packages` (typical - single domain)
- `backend` + `security` (optional - security issue in backend code)
- `user-auth` + `testing` (optional - missing tests for auth feature)

Process:

- Analyze file paths (match to functional/technical domains)
- Extract keywords from issue content
- Prefer existing labels over suggested new labels
- Use labels from Phase 4 (existing + approved new labels)

Labels are auto-assigned here but user can modify during Phase 7 (interactive review).

### Phase 6: User Story Conversion

**Only ask if feature-like issues exist.**

Check if any issues have types like: feature, enhancement, story, epic, improvement, capability

**If YES** (feature-like issues present):

Ask: "Format feature/enhancement descriptions as user stories?"

- "As a [user], I want [goal] so that [benefit]"

If yes:

- **Keep titles short and clear** (do NOT convert titles to user story format)
- **Rewrite Description section only** in user story format for feature-like types
- Leave bug, task, chore, etc. unchanged

**If NO** (only bug, task, chore, etc.):

Skip this phase entirely. User stories don't apply to these types.

### Phase 7: Interactive Issue Review

**Title Formatting Conventions:**

Format titles based on issue type:

- **Bugs**: Describe what's wrong (problem state), not what to add/fix
  - Good: "Shell scripts fail silently without error handling"
  - Bad: "Add error handling to shell scripts"
- **Tasks**: Verb-based action to take
  - Good: "Extract duplicate validation logic"
  - Good: "Refactor macOS defaults script"
- **Features**: Describe the capability, not the action
  - Good: "User authentication" or "User authentication system"
  - Bad: "Add user authentication"

**Organize issues by:** Source → Label → Priority (desc)

Present in batches of 5-10 issues at a time:

```text
=== Batch 1/4: TODOs ===

1. [bug] Shell scripts fail silently without error handling
   Labels: infrastructure, security
   Source: TODO in scripts/setup.sh:106

   Details:
   Add error handling to installation scripts.
   Currently scripts can fail silently.

2. [task] Extract duplicate validation logic
   Labels: code-quality
   Source: TODO in src/validators/user.ts:42

   Details:
   Validation logic duplicated across user and profile validators.
   Extract to shared utility.

---

Actions:
- (a)pprove batch - Approve all issues in this batch
- (s)kip batch - Skip all issues in this batch
- (e)dit {number} - Edit issue (title, body, type, labels) (e.g., "e 1")
- (d)elete {number} - Delete specific issue (e.g., "d 2")
- (n)ext - Show next batch
- (f)inish - Done reviewing, create approved issues

Choice:
```

**For edit:**

When user edits an issue, present interactive prompts:

```text
Editing issue #1: Shell scripts fail silently without error handling

Current type: bug
New type (or Enter to keep): [allow changing to any valid type]

Current title: Shell scripts fail silently without error handling
New title (or Enter to keep): [allow editing]

Current labels: infrastructure, security
Available labels: [list all existing + approved new labels from Phase 4]
New labels (comma-separated, or Enter to keep): [allow editing]

Current body:
---
Add error handling to installation scripts.
Currently scripts can fail silently.
---
Edit body? (y/n): [if yes, allow multi-line editing]

Save changes? (y/n):
```

**Label similarity detection:**

When user enters a new label name that doesn't exist, check for similar labels:

1. **Substring matching**: Check if new label is contained in or contains existing labels

   - User types: "test" → finds "testing", "tests"
   - User types: "testing" → finds "test", "tests"

2. **Simple similarity**: Check for common typos or plurals
   - User types: "securtiy" → finds "security"
   - User types: "doc" → finds "docs", "documentation"

If similar labels found:

```text
Similar labels found:
  1. testing - Automated testing and test infrastructure
  2. tests - Test files and test utilities

Options:
- Use one of these (enter number): [allow selection]
- Create new label "test": [press Enter]
- Show all labels: [type 'list']
```

If user creates a new label during editing, add it to the approved labels list for this session (available for other issues being edited).

**Track state:**

- Approved issues (will be created)
- Skipped issues (won't be created)
- Deleted issues (removed from consideration)

### Phase 8: Create Required Labels

After interactive review, determine which labels are actually needed:

```bash
# Collect unique labels from all approved issues
# Compare against existing labels from Phase 1.3
# Create only labels that don't exist yet and are assigned to approved issues
```

For each new label needed:

```bash
gh label create "{name}" --description "{description}" --color "{auto-generate-color}"
```

This ensures we only create labels that will actually be used, avoiding label clutter from rejected issues.

### Phase 9: Create Issues

For each approved issue, format the body to match the template structure.

#### For TODOs: Determine permalink strategy

Get current commit SHA for permalinks:

```bash
git rev-parse HEAD
```

For each TODO, read surrounding context (±5 lines) and judge:

- **Contextually related**: TODO describes work specific to that function/block
  - Example: `# TODO: Add retry logic to this API call` in an API handler function
  - Strategy: Reference naturally in description, no permalink needed
- **Not contextually related** (or unclear): TODO just happened to be placed there
  - Example: `# TODO: How do I add git sub command completions like git-ignore?` in a plugin list
  - Strategy: Include GitHub permalink in Additional Context

**Format permalink:**

```text
https://github.com/{owner}/{repo}/blob/{commit-sha}/{file}#L{line}
```

**Format issue body dynamically:**

Use the template structure parsed in Phase 1.2. For each section heading found in the template:

1. Match section purpose to content type:

   - **Description sections** (Description, Summary, What, etc.): Main issue description or user story
   - **Steps/Reproduce sections** (Steps to Reproduce, How to Reproduce, etc.):
     - If TODO and contextually related: describe location naturally
     - If TODO and not contextually related: "See Additional Context"
     - If from analysis: list steps
     - Otherwise: "Not applicable"
   - **Environment sections** (Environment, System, Platform, etc.): Platform info if relevant, else "Not applicable"
   - **Criteria sections** (Acceptance Criteria, Success Criteria, Definition of Done, etc.): Checklist items with `- [ ]`
   - **Checklist sections** (Checklist, Tasks, To Do, etc.): Task items with `- [ ]`
   - **Context sections** (Additional Context, Notes, References, etc.):
     - If TODO and not contextually related: GitHub permalink
     - Other file references, links, extra details

2. If template has sections not listed above, make best effort to populate based on section name

3. If no template structure available, use minimal format with description and optional file references

Create issue with formatted body (using dynamically generated markdown from steps above):

```bash
gh issue create \
  --repo {owner}/{repo} \
  --title "{title}" \
  --body "{formatted_body}" \
  --label "{label1,label2,label3}"
```

Capture issue number and node ID from response.

### Phase 10: Set Issue Type

If templates exist, set type field via GraphQL:

```bash
gh api graphql -f query='
  mutation($issueId: ID!, $issueTypeId: ID!) {
    updateIssue(input: {
      id: $issueId
      issueTypeId: $issueTypeId
    }) {
      issue { id }
    }
  }
' -f issueId="{issue_node_id}" -f issueTypeId="{type_id}"
```

### Phase 11: Add to Project Board

For each created issue:

```bash
gh api graphql -f query='
  mutation($projectId: ID!, $contentId: ID!) {
    addProjectV2ItemByContentId(input: {
      projectId: $projectId
      contentId: $contentId
    }) {
      item { id }
    }
  }
' -f projectId="{project_id}" -f contentId="{issue_node_id}"
```

Set status to "Backlog":

```bash
gh api graphql -f query='
  mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: ID!) {
    updateProjectV2ItemFieldValue(input: {
      projectId: $projectId
      itemId: $itemId
      fieldId: $fieldId
      value: { singleSelectOptionId: $optionId }
    }) {
      projectV2Item { id }
    }
  }
'
```

### Phase 12: Output Summary

```text
Created 12 issues:

TODOs:
- #45: [bug] Installation scripts fail silently without error handling [infrastructure, security]
- #46: [task] Extract duplicate validation logic [code-quality]

Markdown files (docs/plans/):
- #47: [feature] User authentication system [backend, security]
- #48: [feature] Data export functionality [frontend]

Code review:
- #49: [bug] Missing input validation in API endpoints [backend, security]
- #50: [task] Split monolithic service class [backend, code-quality]
...

All issues added to project board "{board-name}" in Backlog status.

Skipped: 3 issues
Deleted: 1 issue
```

### Phase 13: Cleanup Source Files

**IMPORTANT**: Only offer cleanup, never delete automatically.

Ask: "Delete completed TODO comments and markdown files?"

If yes, present cleanup options:

```text
Files eligible for cleanup:

TODOs created as issues:
- home/dot_config/zsh/dot_zsh_plugins.txt:34
- home/dot_config/zsh/zshrc.d/zoxide.zsh:5

Markdown files created as issues:
- docs/plans/raycast-backup.md
- docs/plans/synology-support.md

Options:
- (a)ll - Delete all TODOs and markdown files listed above
- (t)odos only - Delete only TODO comments
- (m)arkdown only - Delete only markdown files
- (s)elect - Choose specific files to delete
- (n)one - Skip cleanup (keep all files)

Choice:
```

**For TODO deletion:**

Use sed to remove the TODO line:

```bash
# For each TODO line
sed -i '' '{line_number}d' {file_path}
```

Verify the change and show diff before finalizing.

**For markdown file deletion:**

```bash
rm {file_path}
```

Show list of deleted files after cleanup completes.

## Key Principles

1. **Types come from templates** - Never hardcode bug/feature/task
2. **Labels are domain-based** - Represent areas of the codebase, not priority/urgency
3. **Labels informed by context** - Parse issues FIRST, then suggest labels based on both repo structure AND actual issue content
4. **Similarity detection** - Prevent duplicate labels by detecting similar names during editing (substrings, typos, plurals)
5. **Interactive review** - Show batches with issues AND labels together, allow editing before creation
6. **Ordered presentation** - Group by source → label → priority desc
7. **User approval required** - For labels, for issues, for everything
8. **Smart permalinks** - For TODOs, judge context and only add GitHub permalinks when TODO isn't related to surrounding code
9. **Cleanup is optional** - Offer to delete TODOs/markdown files after creating issues, never do it automatically
10. **Only create used labels** - Labels are created in Phase 8 AFTER review, not before, avoiding clutter from rejected issues
