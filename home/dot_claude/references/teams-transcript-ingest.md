# Teams Meeting Transcript Ingest

_Getting a Teams meeting transcript into a clean, attributed note. The hard
part is getting the file at all; the processing is easy once you have it._

## Getting the transcript (the hard part)

_Non-owners often can't download the VTT. Try these in order; none is reliable._

The transcript download is gated by meeting-owner permission. As a member
(not the organizer), the download option frequently does not appear in the
Teams UI, even when you attended. This is the main blocker.

Try in order:

1. **Ask the owner.** Have the meeting organizer download the `.vtt` and send
   it, or grant you access to the recording/transcript. This is the only path
   that has worked repeatedly. It takes a round-trip, so ask early.
2. **Pull it from the backing store in the browser.** The transcript lives in
   Stream / SharePoint behind the Teams UI. Following those URLs in the browser
   has retrieved the `.vtt` directly at least once - but it was **not
   reproducible** on a later meeting and the reason was never found. Treat it as
   a lucky path, not a procedure: try it, don't count on it.

**What does not work: copy-paste from the Teams transcript pane.** The pane
lazy-loads only the portion you've scrolled into view, so a copy grabs a
partial, often garbled transcript. Don't rely on it.

**Unsolved - a meeting note-taker would remove this whole section.** The
recurring need is a recorder/transcriber that works across Teams, join.me, and
Google Meet, does not require the organizer to admit a bot or grant
permission, and is free and privacy-friendly. Not yet chosen. Until then,
acquisition stays manual and flaky.

## Processing the VTT

_Strip the WebVTT to dense `Speaker: text` lines before reading or distilling._

A raw Teams `.vtt` is mostly cue numbers and timestamps. Collapse it to one
speaker-tagged line per cue:

```sh
grep '<v ' transcript.vtt | sed -E 's/<v ([^>]+)>/\1: /g; s#</v>##g'
```

This turns `<v Jane Doe>text</v>` cues into `Jane Doe: text`, dropping the
timestamp noise and cutting read cost by roughly 4x. A long transcript may
still exceed one read - read it in chunks.

## Speaker attribution

_The VTT labels are not trustworthy. Verify against content; caveat what you
can't verify._

- **A shared conference-room device puts several people on one audio feed.**
  Teams tags the whole feed with one name (the room or one attendee), so two
  people in the same room are indistinguishable in the transcript. You cannot
  recover who said what from the VTT alone.
- **Even separate attendees get mislabeled.** The speaker tag has been wrong
  for people joining on their own devices. Don't assert a quote's speaker as
  fact on the strength of the label.

When labels are clean and match the attendees, attribute directly. When a room
device, missing labels, or a suspect tag is in play, infer from content and
role, and add a short speaker-caveat note at the top of the distilled note
explaining the inference. Never invent precision you don't have.

## Distilling into a note

_Once stripped and attributed, follow the knowledge conventions._

The transcript is a `transcript` source: it stays raw in `sources/`; the
knowledge goes in a separate linked `meeting` note. See
`~/.claude/knowledge-conventions.md` for the metadata model and placement.

For the meeting note, use these sections: purpose, what changed, decisions
made, decisions needed, action items (owner / due / confidence only if stated -
never invent), risks and blockers, open questions, reusable pattern
candidates, source caveats (including any attribution uncertainty from above).
