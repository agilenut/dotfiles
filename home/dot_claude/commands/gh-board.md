---
title: GitHub Project Board
description: Create or select a GitHub project board for the current repo
allowed-tools: Bash(gh:*), Bash(git:*), AskUserQuestion
argument-hint: "[create | select]"
---

Create or select a GitHub project board linked to the current repository.

## Arguments

$ARGUMENTS

- `create` - Create a new project board
- `select` - Select an existing project board
- (no args) - Ask which action to take

## Process

### 1. Detect Repository Context

```bash
git remote get-url origin
```

Parse owner and repo from the URL. If no remote, ask user for owner/repo.

### 2. Determine Owner Type

```bash
gh api users/{owner} --jq '.type'
```

- If `"User"` → project will be created at user level (no choice needed)
- If `"Organization"` → ask: "Create project at org level or your personal level?"

### 3. Check Existing Projects

```bash
# For user projects
gh project list --owner @me --format json

# For org projects (if applicable)
gh project list --owner {org} --format json
```

If `select` argument or user chooses to select existing:

- List available projects
- Let user pick one
- Link to repo if not already linked

### 4. Create New Board (if `create` or user chooses)

Ask for project title (suggest repo name as default).

Present default Status field values for confirmation:

```text
Suggested columns:
- Backlog (default for new issues)
- Todo
- In Progress
- In Review
- Blocked
- Done

Want to customize these? (Y/n)
```

Allow user to add, remove, or rename columns.

Create the project:

```bash
# For user
gh project create --owner @me --title "{title}"

# For org
gh project create --owner {org} --title "{title}"
```

### 5. Configure Status Field

Get project ID and configure Status field options via GraphQL:

```bash
gh api graphql -f query='
  mutation($projectId: ID!, $fieldId: ID!, $options: [ProjectV2SingleSelectFieldOptionInput!]!) {
    updateProjectV2Field(input: {
      projectId: $projectId
      fieldId: $fieldId
      singleSelectOptions: $options
    }) {
      field { id }
    }
  }
' -f projectId="{id}" -f fieldId="{status_field_id}" -f options='[...]'
```

### 6. Link to Repository

```bash
# Get repo node ID
gh api repos/{owner}/{repo} --jq '.node_id'

# Link project to repo
gh api graphql -f query='
  mutation($projectId: ID!, $repositoryId: ID!) {
    linkProjectV2ToRepository(input: {
      projectId: $projectId
      repositoryId: $repositoryId
    }) {
      repository { id }
    }
  }
' -f projectId="{project_node_id}" -f repositoryId="{repo_node_id}"
```

### 7. Output

Print:

- Project URL
- Configured columns
- Next step suggestion: "Board ready. Next step: `/gh-issue-templates` (enables issue types) or `/gh-issues` to add issues."

## Notes

- Project board context can be used by `/gh-issues` if run in same session
- Use `gh project list` to see all projects
- Use `gh project view {number}` to see project details
