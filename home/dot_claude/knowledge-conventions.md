# Knowledge Repo Conventions

_Shared conventions for personal knowledge repos served through Basic Memory.
Each repo's `AGENTS.md` imports this via `@~/.claude/knowledge-conventions.md`._

## What these repos are

_Curated markdown knowledge, one git repo per unit, indexed by Basic Memory._

The goal is a distilled brain, not a data lake: curate at the door, prune over
time. One unit (a project or life domain) per repo.

## Folders

_A capture-to-curated pipeline; raw provenance kept aside._

- `inbox/` - unprocessed captures awaiting triage.
- `sources/` - raw provenance (transcripts, emails, recordings, clipped
  articles). Gitignored; kept on disk and NAS-backed; still Basic-Memory-indexed.
- genre/domain folders (e.g. `meetings/`, `synthesis/`, `reference/`) - the
  curated knowledge.
- `archive/` - superseded material.

## Metadata model

_Four mechanisms, one per axis. Don't cram everything into tags._

| Axis                 | Mechanism         | Values                                        |
| -------------------- | ----------------- | --------------------------------------------- |
| Lifecycle stage      | `status` field    | `raw · draft · published · archived`          |
| What kind of note    | `type` field      | see vocab below (BM-native, schema-validated) |
| Subject + flags      | `tags` list       | controlled; reuse before invent               |
| Things + connections | relations `[[ ]]` | people, products, repos as nodes              |

Optional fields where they apply: `person` (whose, e.g. dad vs me), `series` +
`session` (a meeting set), `confidentiality` (`private`/`shareable`).

### `status`

`raw` (captured, unprocessed) -> `draft` (being written) -> `published`
(finalized, trusted) -> `archived` (superseded).

### `type`

Captures (usually `status: raw`, in `sources/`), typed by format:
`email · transcript · recording · document · link · capture`

Knowledge, typed by genre:
`meeting · synthesis · reference · runbook · decision · assessment · record ·
profile · idea · troubleshooting`

Definitions where they're easy to confuse:

- `reference` - how something works, or stable facts you look up repeatedly.
  Not the same as citing an article (that's a `link` capture).
- `runbook` - step-by-step actions to do something.
- `record` - a discrete fact or event with data (a car service, a tax filing,
  a purchase); often has an attachment.
- `profile` - a node for a thing (person, company, product, vendor, account)
  that other notes link to. Avoid the word "entity" - Basic Memory already
  calls every note an entity.
- `synthesis` - distilled, cross-source knowledge.

A raw artifact and the knowledge drawn from it are SEPARATE, linked notes: the
`email`/`transcript` stays `raw` in `sources/`; the distilled
`synthesis`/`decision`/`meeting` note links `[[the source]]`. Artifacts don't
become knowledge - you extract knowledge from them.

**Attachments carry content - read them.** An email or document often puts the
substance in an embedded image or attachment (a screenshot, a signed PDF, a
diagram), not the body text. Don't treat an attachment as opaque provenance,
and don't assume a referenced file just repeats the note that mentions it -
open it. For an `.eml`, an inline image is usually a base64 MIME part: find the
`Content-Type: image/...` part and decode its base64 block to a file (`base64
-D` on macOS); other attachments may carry a different encoding. Fold what it
shows into the distilled note; the raw stays in `sources/`.

Ingesting a meeting or Teams transcript is its own small procedure (getting the
file is often the hard part): see `~/.claude/references/teams-transcript-ingest.md`.

### `tags`

Subjects (the topic: `api`, `auth`, `taxes`, `networking`, `mac`) plus a few
flags (`reusable`, `action-needed`, `sensitive`). Lowercase-kebab. Reuse an
existing tag before inventing one. Subjects and flags only - never lifecycle
(that's `status`) or proper nouns (those are relations).

### relations `[[ ]]`

Entities - people, products, vendors, repos - get a node; notes link to them.
This makes the graph queryable without tag soup. Prefer a relation over a tag
for any proper noun.

## Naming

_Stem by type. One-off dated events take a date prefix; stable references take
a topic slug; recurring and batched records have their own forms._

- **One-off dated event** - a `meeting`, a `decision`, an invoice, a single
  `record` - takes a `YYYY-MM-DD-<slug>` prefix.
- **Stable reference** - `reference`, `runbook`, `profile`, `synthesis`,
  `idea`, `assessment`, `troubleshooting` - takes a `<topic-slug>`, no date.
- **Recurring readout, one file per period** - a cost or usage snapshot you
  re-take on a schedule - takes a date _suffix_ so the topic sorts first:
  `<topic>-YYYY-MM` (or `-YYYY-MM-DD` for day-grain).
- **A batch of records for one period** - several files belonging to the same
  month - group under a dated folder (`billing/2026-07/`) with plain
  `<topic-slug>` files inside.
- **A raw source shares the stem of the note it feeds**, so the pair sits
  together (a transcript and its meeting note share one stem). A standalone
  capture that feeds no note takes a descriptive `<topic-slug>`.

**Date it or not?** Date a note when its content is a state that goes stale and
gets superseded by a fresh version (a cost readout, a usage snapshot, a review
as-of a date). Leave it undated when it's an evergreen fact you correct in
place.

## What to store - the threshold

_Curate at triage. A distilled brain, not a data lake._

Store something when, mostly:

1. You'll need it again.
2. It's hard to re-derive if you don't keep it (email lives in your mail
   archive, public articles are online - low value to store).
3. It carries a decision, fact, how-to, or context you'd otherwise re-explain.
4. It's about your world (your setup, projects, decisions), not generic info.

Tiers: distill into a typed note · capture a `link` · clip full content (if
important and at risk of disappearing) · don't store.

Not an email archive: distill the few knowledge-bearing emails; leave the rest
in your mail app. Same for the web - clip what's important and link-rot-prone,
link the rest, store nothing for the ephemeral.

Not a status mirror either. When a live source already answers a question (an
issue tracker, a code repo's docs, a lockfile), name the source and stop. Keep
what it can't answer: why the work exists, what was decided and rejected, how
it was sequenced. A dated one-line snapshot is fine when the history needs it;
a status table or a restated rule is not, because nothing keeps it in step with
its source.

## Write for the question, not the answer

_Notes are reached by search, not loaded. Lead with the question and both
halves of the search find you._

Retrieval is hybrid - semantic plus full-text - so wording pays twice. Lexical
overlap is scored directly, and the semantic half embeds the whole note, so
everything else in it dilutes the part that answers. A note written in the
vocabulary of its answer loses to a neighbour that happens to carry the words
in the question.

**Put the question in the TL;DR line**, in the words someone would actually
use, then answer it. That slot is already under every heading; this only says
what belongs in it. Where a search would plausibly land on a neighbouring note
first, link across so the landing is a hop rather than a dead end.

**Exempt the types reached by literal terms.** A `record` is found by invoice
number, vendor or year; a `troubleshooting` note by the error string someone
pastes. Keep those verbatim - paraphrasing an error string into a question
makes it unfindable.

**Aggregate questions are structural, not lexical.** "Which clients do we have"
can't be won by rewording any one client profile: the question is about the set
and the note is about a member. That wants a `type` or `tags` query, or a hub
note that lists them. Reword only when a single note genuinely is the answer.

Verify with `basic-memory reindex -p <project>`, then search two or three
phrasings a reader would try. Top three is the bar - chasing rank one is how
padding starts. One extra phrasing per note is the ceiling; past that you
crowd the note's own embedding and it matches everything weakly.

Observed: a proctoring note ranked first for `proctoring` and fell out of the
top three for "can we stop students cheating during an assessment"; a billing
runbook lost "how do I bill a client" to `AGENTS.md`.

Apply to new writing. Don't retrofit - fix an old note when a search actually
fails you. When reading, try a second phrasing before concluding a note doesn't
exist.

## Project and client

_Covered by the repo, not per-note tags._

The project is the repo; Basic Memory stamps every result with the
`<project>/...` permalink; the client lives in the repo's `AGENTS.md`. Don't
add per-note project/client tags. Cross-project grouping (e.g. all of one
client) is a project-level concern, handled later if needed.

## Workflow

_Knowledge repos, not code projects - lighter rules apply here._

- Commit directly to `main`. No branches, PRs, CI, or build/test.
- Auto-commit at natural checkpoints with clear messages; routine edits don't
  need to be asked first.
- Review gate = the git diff: for bulk Claude-generated changes (reflect,
  defrag), surface the diff before committing.
- Local-only by default - never push unless a repo is explicitly set up to sync.
