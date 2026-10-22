---
name: voice
description: "Use when user asks to write or rewrite content in their voice - generic drafting, rewrites, casual replies, or content with no specific destination skill. Also when explicitly invoked as /voice. Destination-specific skills (pr-comment, future email-draft/gh-issue/imessage) compose this one and layer channel-specific patterns on top."
user-invocable: true
argument-hint: "<content to rewrite | file path | describe what to write>"
---

# Voice Skill

Rewrite or draft content in the user's voice, applying the generic
voice rules from the styleguide.

## When to invoke

- User says `/voice` with content to rewrite, a file path, or a
  description of what to write
- User asks "rewrite this in my voice" / "draft this as me" / "make
  this sound like me"
- Other skills compose this for destination-specific writing (e.g.
  `pr-comment` calls voice for the body, layers on PR-specific
  patterns)

If the user names a destination (PR comment, email, GH issue, casual
message) and a dedicated skill exists for it, use that skill instead -
it loads voice's rules plus its own channel-specific file.

## Prerequisite: load the styleguide

Load `~/repos/voice-samples/styleguide/generic.md`. If the file doesn't
exist, the user hasn't cloned the private `voice-samples` repo on this
machine. Tell them to run:

```bash
gh repo clone agilenut/voice-samples ~/repos/voice-samples
```

Do not proceed without the styleguide.

The styleguide is split across files in `~/repos/voice-samples/styleguide/`:

- `generic.md` - Hard rules, Context drivers, Patterns, Word choice,
  Personas. This skill applies this file only.
- `<destination>.md` (pr-comment.md, email.md, gh-issue.md, imessage.md)
  - destination-specific patterns loaded by destination skills.

## Step 1: Identify input and destination

Parse the argument:

- A file path (`.md`, `.txt`, `.eml`, etc.) → read it
- Content as text → use directly
- A description of what to write → draft fresh content

Identify the destination if known (PR comment, email, GH issue,
casual message). If unclear and it matters for the output, ask. If
not stated and not crucial, default to a neutral peer tone and
ask after producing the draft.

## Step 2: Evaluate context drivers

From the styleguide's Context Drivers section, work out:

- Current-state issue or future risk on working code?
- Is the fix the same as the diagnosis?
- How well does the user know this area? How well does the audience?
- Is this clear-cut or a judgment call?
- Stakes: blocker / nice-to-have / FYI?
- Localized fix or distributed?

These choices drive which patterns to use in Step 3.

## Step 3: Apply voice rules

Load and apply rules in layers:

- **Universal output rules** - `~/.claude/CLAUDE.md` Language section
  (em-dashes, banned phrases from "Phrases I never use", concision,
  clarity, no "Suggesting..." gerund-as-subject). Always in context.
- **Generic voice hard rules** - `generic.md` Hard rules section
  (currently: don't construct signatures).
- **Generic voice patterns** - `generic.md` Patterns section. Pick
  patterns based on the context drivers from Step 2 (hedging verbs,
  acknowledgment lead vs factual lead, action-first vs observation-
  first, "Needs:" + bullets, state-evidence-let-inference-land,
  apologize-for-mistakes-not-inconvenience, short casual responses,
  argument/persuasion style, etc.).
- **Word choice** - `generic.md` Word choice section. Apply user-
  specific translations and watch context-dependent terms.

## Step 4: Draft

Write the content using the chosen patterns. Don't list which rules
you applied - just produce the draft.

## Step 5: Cut-pass

Review the draft. For each sentence:

- Does it carry real meaning? If not, cut.
- Is there a tighter version? Apply it.
- Anti-padding: cut "Hope this helps" / "Let me know if you have
  questions" / similar tail filler.
- Multiple paragraphs that could be one? Combine, but don't drop
  substance.

**Don't strip out concrete specifics** (file names, line numbers,
exact phrasings, fix syntax, quantified impact) - those earn their
place. The cut-pass removes filler, not signal.

## Step 6: Validate

Scan the draft against the rules loaded in Step 3:

- No em-dashes (—); use " - " sparingly as a separator
- No phrases from CLAUDE.md's "Phrases I never use" table
- No bare role nouns for app sections ("the admin" → "the admin app")
- First-person verbs for suggestions ("I'd suggest" not "Suggesting")
- Context-dependent terms used only in appropriate contexts (per
  `generic.md` Word choice)
- Signatures not constructed (unless destination can't auto-add)

If any violation, fix and re-validate.

## Step 7: Output

Provide just the rewritten content. No commentary about which rules
were applied or what changed. If the user asks what changed, then
explain.

If the situation calls for a real choice (e.g. direct vs question
framing, action-first vs observation-first) and both fit, present
both as alternatives briefly. Don't fabricate alternatives just to
seem thorough.

## Iteration

If the user pushes back on the draft, iterate. Common adjustments:

- "Too long" → another cut-pass, harder this time
- "Too short" → check if specifics were stripped that shouldn't have
  been; restore them
- "Too direct" → soften with hedging verbs or question framing
- "Too hedged" → drop the hedges, action-first

After each iteration, save any new patterns or word choices the user
teaches by suggesting an edit to the styleguide.

## Out of scope

- This skill does NOT handle destination-specific formatting (PR body
  headers, email signatures, etc.). Those live in destination-specific
  skills (`pr-comment`, etc.) that compose this one.
- This skill does NOT do extraction or analysis of voice samples.
  That's a separate one-time pipeline in `~/repos/voice-samples/scripts/`.
