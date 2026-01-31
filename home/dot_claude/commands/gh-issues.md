---
title: GitHub Issues from Sources
description: Create GitHub issues from TODOs, files, folders, or inline descriptions
allowed-tools: Bash(gh:*), Bash(git:*), Read, Glob, Grep, AskUserQuestion
argument-hint: '[--todos] [path/to/file.md] [path/to/folder/] ["inline description"]'
---

Create GitHub issues from multiple sources and add them to a project board.

## Arguments

$ARGUMENTS

Sources are **additive** - combine multiple in one invocation:

```bash
/gh-issues                              # Interactive - asks for sources
/gh-issues --todos                      # Parse TODO/FIXME/HACK/XXX from code
/gh-issues docs/plans/                  # Parse all .md files in folder
/gh-issues docs/features.md             # Parse single file
/gh-issues "Add CI/CD pipeline"         # Create from inline description
/gh-issues --todos docs/plans/ "Also fix the login bug"  # Combine all
```

## Process

### 1. Detect Repository and Board

```bash
git remote get-url origin
gh project list --owner @me --format json
```

If multiple boards exist, ask which to use. If none, suggest running `/gh-board` first.

### 2. Check for Issue Templates

```bash
ls .github/ISSUE_TEMPLATE/ 2>/dev/null
```

If no templates exist:

- Warn: "No issue templates found. Issue types won't be available."
- Ask: "Run `/gh-issue-templates` first to enable issue types, or continue without?"

### 3. Fetch Existing Labels

```bash
gh label list --json name,description,color
```

Store for later matching and suggestions.

### 4. Parse Input Sources

#### 4a. From `--todos`

```bash
grep -rn 'TODO\|FIXME\|HACK\|XXX' --include='*.sh' --include='*.zsh' --include='*.ts' --include='*.js' --include='*.py' --include='*.go' --include='*.md' .
```

For each match, extract:

- File path
- Line number
- Comment text (strip TODO/FIXME prefix)
- Create issue with link to file:line

#### 4b. From folder path (e.g., `docs/plans/`)

```bash
ls {folder}/*.md
```

For each file:

- Title: First `# heading` or filename (without extension)
- Body: File content (or summary if too long)
- Treat as feature/epic

#### 4c. From single file

- If structured (`## / ### / - [ ]`): Parse as before
- If free-form: Title from heading, body from content

#### 4d. From inline text

Parse natural language. User says "Add dark mode support" → create issue with that title.

### 5. User Story Conversion (Optional)

Ask: "Want to format issues as user stories? (As a [user], I want [goal] so that [benefit])"

If yes, rewrite each issue:

- Original: "Add dark mode support"
- Converted: "As a user, I want dark mode so that I can reduce eye strain at night"

### 6. Label Matching

For each issue:

1. Check if content matches existing labels (keyword matching)
2. Suggest existing labels that apply
3. If no match, suggest creating new label (confirm first)

Present label suggestions:

```text
Issue: "Add Synology support"
Suggested labels:
  - enhancement (existing)
  - platform (new - create?)
```

### 7. Present Issues for Review

Before creating anything, show full list:

```text
Ready to create 5 issues:

1. [feature] Add Synology SSH support
   Labels: enhancement, platform
   From: docs/plans/synology-support.md

2. [todo] Parameterize computer name in macOS defaults
   Labels: enhancement
   From: TODO in run_once_after_configure-macos-defaults.sh.tmpl:106

3. ...

Proceed? (Y/n/edit)
```

Allow user to:

- Approve all
- Edit individual issues
- Remove issues from list
- Change labels

### 8. Create Issues

For each approved issue:

```bash
gh issue create \
  --repo {owner}/{repo} \
  --title "{title}" \
  --body "{body}" \
  --label "{labels}"
```

If milestone specified:

```bash
--milestone "{milestone}"
```

### 9. Add to Project Board

Get issue node ID and add to project:

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

### 10. Set Issue Type (if templates exist)

If issue templates are configured, set the issue type via GraphQL:

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
'
```

### 11. Output Summary

```text
Created 5 issues:
- #12: Add Synology SSH support [enhancement, platform]
- #13: Parameterize computer name [enhancement]
- ...

All added to project board "dotfiles" in Backlog status.
```

## Notes

- Labels are applied during creation, not after
- Issues are created in the order presented
- Use `gh issue list` to see all issues
- Use `gh project item-list {number}` to see board items
