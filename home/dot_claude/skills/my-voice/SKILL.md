---
name: my-voice
description: "Use when user asks to write or rewrite content in their voice - generic drafting, rewrites, casual replies, or content with no specific destination skill. Also when explicitly invoked as /my-voice. Destination-specific skills (pr-comment, future email-draft/gh-issue/imessage) compose this one and layer channel-specific patterns on top."
user-invocable: true
argument-hint: "<content to rewrite | file path | describe what to write>"
---

# My Voice Skill

Rewrite or draft content in the user's voice, applying the generic
voice rules from the styleguide.

## When to invoke

- User says `/my-voice` with content to rewrite, a file path, or a
  description of what to write
- User asks "rewrite this in my voice" / "draft this as me" / "make
  this sound like me"
- Other skills compose this for destination-specific writing (e.g.
  `pr-comment` calls `my-voice` for the body, layers on PR-specific
  patterns)

If the user names a destination (PR comment, email, GH issue, casual
message) and a dedicated skill exists for it, use that skill instead -
it loads `my-voice`'s rules plus its own channel-specific file.

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
  Personas. Always applied.
- `<destination>.md` (pr-comment.md, email.md, gh-issue.md,
  imessage.md) - destination-specific patterns. A destination skill
  loads its own file. When a destination has a file but no skill
  (currently email), this skill loads that file in Step 1.

## Step 1: Identify input and destination

Parse the argument:

- A file path (`.md`, `.txt`, `.eml`, etc.) → read it
- Content as text → use directly
- A description of what to write → draft fresh content

Identify the destination if known (PR comment, email, GH issue,
casual message). If unclear and it matters for the output, ask. If
not stated and not crucial, ask after producing the draft.

If the destination is email, read
`~/repos/voice-samples/styleguide/email.md` now.

Identify who the reader is to the user (client, teammate, friend).
Look the reader up in the user's Basic Memory knowledge base (client
profiles list client contacts), or infer the relationship from the
thread. If it's still unknown and would change the draft, ask before
drafting.

## Step 2: Evaluate context drivers

Work through every question in `generic.md` Context drivers. For a
reply, the first two matter most: who the reader is to the user,
and what they asked. These answers drive which patterns to use in
Step 3.

## Step 3: Apply voice rules

Load and apply rules in layers:

- **Universal output rules** - `~/.claude/CLAUDE.md` Language section
  (em-dashes, banned phrases from "Phrases I never use", concision,
  clarity, no "Suggesting..." gerund-as-subject). Always in context.
  Where `generic.md` lists a phrase as the user's own (for example
  "To be clear,"), the user may use it, even if CLAUDE.md bans it.
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
- **Destination patterns** - the destination file loaded in Step 1
  (openers, closers, per-type variants).

## Step 4: Draft

Write the content using the chosen patterns. Don't list which rules
you applied - just produce the draft.

## Step 5: Cut-pass

Review the draft. For each sentence:

- Does it carry real meaning? If not, cut.
- Is there a tighter version? Apply it.
- Anti-padding: cut reflexive tail filler ("Let me know if you have
  questions").
- Multiple paragraphs that could be one? Combine, but don't drop
  substance.
- When replying to a question or request: does it cover something
  the reader didn't ask about (how something works, background, a
  side finding)? Cut it, unless it corrects a mistake in their work.
- Does it recite the reader's own results back as evidence for an
  answer? Cut it, and state the judgment behind the answer instead.
  Quoting their code or text to point at something stays, and so
  does correcting a mistake in their work.
- Does it spell out a conclusion the reader can draw from the facts?
  Cut it, unless the reader can't draw it or the recommendation is
  the point (`generic.md` "State the evidence").
- Does a paragraph praise parts that are fine and don't stand out?
  Cut it. Keep approval when it is the answer ("Looks good.").

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
- Notes to a client on their own documents or preparation: framed as
  notes, not fixes you assign; no deadlines or plans for their work
- None of the reader's own results recited back as evidence
- No paragraph praising parts that need no change and don't stand out
- A "Good luck" closer names the event when it's known

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

### Capture rules the user teaches

Run this after an iteration where the user's correction states a
rule to follow in future drafts, not just a fix to the current one:

- **Implicit**: correction states a rule - "I never use `<X>`",
  "always say `<X>` instead of `<Y>`", "treat `<X>` as `<Y>`",
  "`<X>` isn't in my voice". Venting ("I always forget the
  closer") isn't a rule - skip.
- **Explicit**: user says `remember`, `capture`, or `save this`.

Otherwise skip.

When triggered:

1. **Pick target** by scope of the rule. When a rule could belong
   to more than one layer, use the first that fits:

   - Applies to any output by Claude, including replies to the user
     (not just drafts as the user) → `~/.claude/CLAUDE.md`
   - Applies when writing as the user, any destination →
     `generic.md`
   - Applies only to one channel → that `<destination>.md`

   A correction that splits across destinations ("in PR comments I
   never do X, in email I do") writes two edits, one per
   destination file.

2. **Pick section** inside the target by rule shape:
   - A banned phrase → "Phrases I never use"
   - A term the user prefers → "Word choice"
   - A usage pattern → "Patterns"
   - A hard constraint → "Hard rules"
   - A destination-specific pattern → the destination's own sections
3. **Check for duplicates**: grep the target section for the rule's
   key phrase. If a matching or near-matching rule is already there,
   show it and ask whether to amend the existing line or skip; don't
   append a duplicate.
4. **Draft the edit**: file, section, exact lines to add or change.
5. **Ask** `apply to <file>:<section>? y / edit / retarget / n`:
   - `y` → apply as drafted
   - `edit` → rewrite the proposed line, then apply
   - `retarget` → name a different voice-samples file or
     `~/.claude/CLAUDE.md` (nothing else is in scope); re-draft
     and re-ask
   - `n` → drop it
   - anything else → re-ask once, then treat as `n`
6. **Apply**:
   - voice-samples target (generic.md or a destination file) →
     Edit the file. If the current branch isn't `main`, surface it
     and ask y/n before committing. Commit with a one-line message
     naming the rule.
   - CLAUDE.md target → delegate to the `dotfiles` skill. It
     handles the worktree, edit, apply, and PR.
7. **Reload** so the next iteration this session uses the new rule.
   A running session keeps its loaded CLAUDE.md, so a captured
   universal rule takes effect next session instead - say so when
   applying one.

## Out of scope

- This skill does NOT handle destination-specific formatting (PR body
  headers, email signatures, etc.). Those live in destination-specific
  skills (`pr-comment`, etc.) that compose this one. Email is the
  exception until an `email-draft` skill exists: this skill loads
  `email.md` itself.
- This skill does NOT do extraction or analysis of voice samples.
  That's a separate one-time pipeline in `~/repos/voice-samples/scripts/`.
