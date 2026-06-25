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

### `tags`

Subjects (the topic: `api`, `auth`, `taxes`, `networking`, `mac`) plus a few
flags (`reusable`, `action-needed`, `sensitive`). Lowercase-kebab. Reuse an
existing tag before inventing one. Subjects and flags only - never lifecycle
(that's `status`) or proper nouns (those are relations).

### relations `[[ ]]`

Entities - people, products, vendors, repos - get a node; notes link to them.
This makes the graph queryable without tag soup. Prefer a relation over a tag
for any proper noun.

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
