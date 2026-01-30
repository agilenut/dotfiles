---
title: New GitHub Project
description: Set up GitHub project with issues, labels, milestones, and project board from a features document
allowed-tools: Bash(gh:*), Bash(git:*), Read, Write, Edit, Glob, Grep, WebFetch, AskUserQuestion
---

Set up a complete GitHub project workflow from a features document.

## Prerequisites

Before running, verify:

1. `gh` CLI is installed: `gh --version`
2. `gh` is authenticated: `gh auth status`
3. If not authenticated, run: `gh auth login`
4. GitHub organization exists (create at github.com/organizations/new if needed)

## Process

### 1. Gather Information

Detect or ask for:

- **Org name**: Check git remote, or ask user
- **Repo name**: Use current folder name as default, or ask user
- **Visibility**: Ask if repo should be public or private
- **Features file**: Default to `docs/features.md`, confirm with user

### 2. Repository Setup

If creating new repo:

```bash
gh repo create {org}/{repo} --{public|private} --description "{description}"
```

If local repo exists and needs remote:

```bash
git remote add origin https://github.com/{org}/{repo}.git
git push -u origin main
```

### 3. Issue Templates

Create `.github/ISSUE_TEMPLATE/feature.md`:

```markdown
---
name: Feature
about: A new feature or user story
labels: ""
---

## Description

<!-- What needs to be done and why? -->

## Acceptance Criteria

<!-- How do we know this is done? -->

- [ ] criteria
- [ ] criteria
- [ ] criteria

## Spec

<!-- Link to detailed spec in docs/specs/ if this feature needs one -->
```

Create `.github/ISSUE_TEMPLATE/bug.md`:

```markdown
---
name: Bug
about: Something isn't working correctly
labels: bug
---

## Description

<!-- What's happening? What did you expect? -->

## Steps to Reproduce

1. Step one
2. Step two
3. Step three

## Environment

<!-- Browser, LMS, user role, etc. if relevant -->
```

Create `docs/specs/README.md` explaining when/how to write specs.
Create `docs/specs/_template.md` with standard spec structure.

### 4. Parse Features Document

Read the features document and extract:

- **Top-level sections** (## headings) -> Milestones (e.g., "## MVP Backlog" -> "MVP")
- **Sub-sections** (### headings) -> Labels (e.g., "### LTI: Integration" -> "lti")
- **Checkbox items** (`- [ ]`) -> Issues

### 5. Present Labels and Columns for Confirmation

**IMPORTANT**: Before creating anything, present to the user:

**Labels** (derived from section headings):

| Label | Color   | Description              |
| ----- | ------- | ------------------------ |
| lti   | #0052CC | LTI integration features |
| ...   | ...     | ...                      |

**Project Columns** (Status field values):

- Backlog (default for new issues)
- Todo
- In Progress
- In Review
- Blocked
- Done

Ask user to confirm or modify these before proceeding.

### 6. Create Labels

For each confirmed label:

```bash
gh label create "{label}" --repo {org}/{repo} --color "{color}" --description "{desc}"
```

Color suggestions:

- Blue (#0052CC) for integration/API
- Green (#0E8A16) for core features
- Purple (#5319E7) for AI/ML
- Orange (#D93F0B) for auth/security
- Yellow (#FBCA04) for UI/UX

### 7. Create Milestones

For each top-level section:

```bash
gh api repos/{org}/{repo}/milestones -f title="{name}" -f description="{desc}"
```

### 8. Create GitHub Project

Create org-level project:

```bash
gh project create --owner {org} --title "{Project Name}"
```

Configure Status field via GraphQL to have these options:

- Backlog, Todo, In Progress, In Review, Blocked, Done

Link project to repo via GraphQL:

```graphql
mutation {
  linkProjectV2ToRepository(
    input: { projectId: "{project_node_id}", repositoryId: "{repo_node_id}" }
  ) {
    repository {
      id
    }
  }
}
```

### 9. Create Issues

For each checkbox item in features document:

1. Parse title from checkbox text
2. Determine label from parent ### heading
3. Determine milestone from grandparent ## heading
4. Format as user story if possible: "As a [user], I want [goal] so that [benefit]"
5. Create issue:

```bash
gh issue create -R {org}/{repo} -t "{title}" -l "{labels}" -m "{milestone}" -b "{body}"
```

1. Set issue type to Feature via GraphQL:

```graphql
mutation {
  updateIssue(
    input: { id: "{issue_node_id}", issueTypeId: "{feature_type_id}" }
  ) {
    issue {
      id
    }
  }
}
```

1. Add to project board with Backlog status via GraphQL

### 10. Manual Steps Output

Print instructions for steps that cannot be automated:

**Create Project Views** (GitHub UI only):

1. Go to the project board
2. Create "Backlog" view:
   - Type: Table
   - Filter: `status:Backlog`
   - Group by: Milestone
3. Create "Sprint Board" view:
   - Type: Board
   - Filter: `-status:Backlog`
   - Columns: Todo, In Progress, In Review, Blocked, Done

**If gh auth needed**:

```bash
gh auth refresh -s project,read:project -h github.com
```

## Customization

- **Label colors**: Modify color mapping above
- **Status values**: Adjust the Status field configuration
- **Issue body**: Change user story format as needed
- **Milestones**: Adjust how sections map to milestones

## Example

```text
/new-gh-proj
```

The skill will:

1. Detect org/repo from git remote or ask
2. Ask if repo should be public or private
3. Find and parse docs/features.md
4. Present labels and columns for confirmation
5. Create all labels, milestones, project, and issues
6. Output manual steps for view creation
