---
name: review-plan
description: "Use when user says /review-plan, asks to review a plan, or wants feedback on an implementation plan before coding"
user-invokable: true
argument-hint: "[plan-filename]"
---

# Plan Review Skill

Review an implementation plan before coding begins.

## Step 1: Find the Plan

1. If argument provided, look for it in `~/.claude/plans/`
2. Otherwise, find the most recently modified `.md` file in `~/.claude/plans/`
3. If no plan found, tell user

## Step 2: Gather Minimal Context

Only collect what the agent can't find on its own:

- The plan content (read the file)
- Issue body if referenced (`gh issue view <N> --json body,title`)
- The project root path (so the agent knows where to explore)

Do NOT pre-read arch docs, CLAUDE.md, or design docs. Let the agent discover and interpret those itself.

## Step 3: Spawn Reviewers (MUST use Task tool — do NOT inline)

You MUST use the Task tool here. Do NOT perform the review yourself.

**Determine if the plan involves UI.** Scan the plan for references to components, pages, routes, views, CSS, styling, design, frontend, or UI frameworks. If yes, include the UX reviewer.

**Always spawn:**

- `subagent_type: "plan-reviewer"`, `description: "Review plan"` — pass the plan content, issue body (if any), project root path, and output path `~/.claude/plan-reviews/<plan-filename>-<YYYYMMDD-HHMMSS>.md`

**Additionally spawn if plan involves UI** (add a second parallel Task call):

- `subagent_type: "ux-reviewer"`, `description: "UX review plan"` — pass the plan content, project root path, and output path `~/.claude/plan-reviews/<plan-filename>-<YYYYMMDD-HHMMSS>-ux.md`

Wait for all Tasks to complete before proceeding.

## Step 4: Present Findings

After all subagents finish:

1. Read the review files written by the subagents
2. Triage: form your own opinion on which findings are worth addressing before coding
3. Present using this exact format. Use markdown links for all file references.

```markdown
## Plan Review: <plan-name>

**Plan:** <VERDICT> — <N> critical, <N> important, <N> suggestions
**UX:** <VERDICT> — <N> critical, <N> important, <N> suggestions ← only if UX reviewer ran

### Findings

1. **[Critical]** (plan)
   Description of the issue and why it blocks implementation.
   **Fix:** what to change in the plan

2. **[Important]** (ux)
   Description and why it matters.
   **Skip:** why it's acceptable as-is

3. **[Alternative]** (plan)
   A different approach the reviewer proposed and why it might be better.
   **Consider:** tradeoffs vs the plan's current approach

4. **[Suggestion]** (ux)
   Description and why it matters.
   **Fix:** quick improvement worth making

...continue single continuous numbering across all severities and reviewers...

Recommended: 1, 3, 4

Full reports: [plan](path) | [ux](path)
```

Format rules:

- ONE continuous numbered list — never restart numbering
- Order: critical first, then important, then alternatives, then suggestions
- Each finding is a mini-block: severity + reviewer on line 1, description on line 2, Fix/Skip/Consider verdict on line 3
- **Fix** = must address before coding. **Skip** = noted but acceptable. **Consider** = alternative approach worth discussing.
- Recommended line lists only the Fix and Consider item numbers
- Omit UX verdict line and report link if UX reviewer was not spawned
- Use markdown link syntax for ALL file references: `[file.cs:42](path/to/file.cs#L42)`

## Rules

- NEVER make changes to the plan — only analyze and report
- Do NOT run mkdir for output directories — Write creates intermediate directories automatically
