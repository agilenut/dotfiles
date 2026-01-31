---
title: GitHub Issue Templates
description: Create issue templates for the repository (.github/ISSUE_TEMPLATE/)
allowed-tools: Bash(git:*), Read, Edit, Write, Glob, Grep, AskUserQuestion
---

Create GitHub issue templates to enable issue types and standardize issue creation.

## Process

### 1. Check Existing Templates

```bash
ls .github/ISSUE_TEMPLATE/ 2>/dev/null
```

If templates already exist, ask: "Issue templates already exist. Overwrite, add new, or cancel?"

### 2. Select Templates to Create

Ask which templates to create:

- [ ] Feature (recommended)
- [ ] Bug (recommended)
- [ ] Task
- [ ] Documentation
- [ ] Custom...

### 3. Create Feature Template

Create `.github/ISSUE_TEMPLATE/feature.md`:

```markdown
---
name: Feature
about: A new feature or enhancement
labels: enhancement
---

## Description

<!-- What needs to be done and why? -->

## Acceptance Criteria

<!-- How do we know this is done? -->

- [ ] Criterion 1
- [ ] Criterion 2

## Additional Context

<!-- Screenshots, links, or other relevant info -->
```

### 4. Create Bug Template

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

<!-- OS, version, browser, etc. if relevant -->

## Additional Context

<!-- Error messages, screenshots, logs -->
```

### 5. Create Task Template (if selected)

Create `.github/ISSUE_TEMPLATE/task.md`:

```markdown
---
name: Task
about: A task or chore that needs to be done
labels: task
---

## Description

<!-- What needs to be done? -->

## Checklist

- [ ] Item 1
- [ ] Item 2
```

### 6. Create Config File (Optional)

Ask: "Create template chooser config? This disables blank issues and requires using a template."

If yes, create `.github/ISSUE_TEMPLATE/config.yml`:

```yaml
blank_issues_enabled: false
```

Note: `contact_links` can be added to link to Discussions or external resources, but is usually not needed.

### 7. Create Specs Directory (Optional)

Ask: "Create docs/specs/ for detailed feature specifications?"

If yes:

Create `docs/specs/README.md`:

```markdown
# Feature Specifications

This directory contains detailed specifications for complex features.

## When to Write a Spec

- Feature requires significant design decisions
- Multiple components or systems involved
- Needs stakeholder review before implementation

## Template

Copy `_template.md` and fill in the sections.
```

Create `docs/specs/_template.md`:

```markdown
# Feature: {Name}

## Summary

One paragraph overview.

## Motivation

Why is this needed? What problem does it solve?

## Detailed Design

### User Experience

How will users interact with this?

### Technical Approach

How will it be implemented?

### API Changes (if applicable)

### Data Model Changes (if applicable)

## Alternatives Considered

What other approaches were evaluated?

## Open Questions

- Question 1?
- Question 2?
```

### 8. Configure Markdown Linting Exclusions

Check if markdown linting is configured:

```bash
grep -l markdownlint .pre-commit-config.yaml 2>/dev/null
```

If markdownlint is configured in pre-commit, add exclusions for issue templates. They start with H2 headings (YAML frontmatter acts as the title) which triggers MD041.

Add an `exclude` pattern to the markdownlint hook in `.pre-commit-config.yaml`:

```yaml
- id: markdownlint
  types: [markdown]
  exclude: ^\.github/ISSUE_TEMPLATE/
```

Note: Using `ignores` in `.markdownlint.yaml` doesn't work when pre-commit passes files explicitly.

### 9. Output Summary

```text
Created issue templates:
- .github/ISSUE_TEMPLATE/feature.md
- .github/ISSUE_TEMPLATE/bug.md
- .github/ISSUE_TEMPLATE/config.yml (optional)
- docs/specs/README.md (optional)
- docs/specs/_template.md (optional)

Issue types are now enabled. Run `/gh-issues` to create issues with proper types.
```

## Notes

- Templates enable GitHub's issue type feature
- Labels in template frontmatter are auto-applied
- Use `blank_issues_enabled: false` to require templates
- Specs directory is optional but recommended for complex projects
