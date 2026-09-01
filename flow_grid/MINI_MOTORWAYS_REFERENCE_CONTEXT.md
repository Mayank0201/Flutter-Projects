# Mini Motorways Reference Context — Read This Before Doing Visual Design Work

This file exists so a future agent (possibly you, possibly a different session) doesn't
have to reconstruct, from scratch, why Mini Motorways keeps coming up in this codebase's
commit history, or trust conclusions that were reached from a genuinely thin evidence base.
Read this in full before touching car sprites, building/destination sizing, or road width.

---

## ⚠️ Read this part first: how "researched" the existing research actually is

Every Mini Motorways conclusion baked into this project so far was produced by looking at
**a handful of official Steam store marketing screenshots** — nothing more.

- Source: images fetched via WebSearch/WebFetch from `store.steampowered.com`, at 1920x1080.
- Method: pixel-level crops and color sampling done in Python on those still images.
- That's it. No gameplay was watched. The game was not installed on this machine at the
  time this research happened.

**Why that matters — this is a weak source, not ground truth:**

- It's a handful of fixed camera angles, zoom levels, and moments a marketing team chose
  to look good in a still frame — not representative gameplay.
- It cannot show motion, the zoom level a real player actually plays at most of the time,
  UI/HUD states, or how the art holds up across different map themes/seasons — only
  whatever happened to be visible in those specific screenshots.
- **It has already produced a wrong conclusion once, caught only on a second, more careful
  pass.** The first pixel-analysis pass concluded Mini Motorways cars have a bold two-tone
  "front cap" — a distinct darker leading-edge block. A later, more careful re-analysis
  found that was a misread: the darker-cap pattern actually belongs to this project's own
  *building* sprite style, not the reference game's car. Mini Motorways' actual cars are a
  single flat, vividly saturated color with much subtler pale inset window bands (roughly
  10–18% of the car's length each) that barely resolve at real gameplay zoom anyway — what
  actually reads as "car" there is saturation + a soft drop shadow + contrast against a
  muted road, not a two-tone paint job.

Treat everything below, and everything already implemented from it, as a **reasonable
first approximation that has already been shown to be capable of being subtly wrong** —
not as verified fact about how Mini Motorways looks or plays.

---

## What Mini Motorways is, and why this project cares

[Mini Motorways](https://dinopolo.club/minimotorways/) (Dinosaur Polo Club) is the explicit
design touchstone for this project (`flow_grid`, a Flutter/Flame traffic-simulation
city-builder). The core mechanic this project borrows is Mini Motorways' central idea:
connect colored houses to same-colored destinations by drawing roads, with a deliberately
minimal, flat, low-detail visual style (no textures, no realism, small easily-readable
shapes).

Several rounds of visual-design work this session — car sprite design, building/destination
sizing, and road-width-vs-lane-fit — were done by researching Mini Motorways' actual shipped
art as a concrete reference point, specifically to ground decisions in *something*, rather
than guessing at what "minimalist traffic game" should look like in the abstract.

**Explicitly NOT being done:** copying any actual Mini Motorways assets. This project uses
its own original, code-generated sprites (drawn procedurally, not traced or extracted
images) and its own color palette throughout. Mini Motorways is a style/proportion
reference only, never an asset source.

---

## The user's situation — real reference material may arrive later

The user does **not** currently have Mini Motorways installed or otherwise available on
this machine — that's the whole reason the Steam-screenshot workaround above was used at
all.

However: the user **does** own/have access to Mini Motorways on their home machine, and has
said that in a **future session** they may hand over a **ZIP file** containing real
reference material captured from their own copy of the game. The user has not specified the
exact contents/format of that zip — it could be gameplay screenshots, a screen recording, or
something else. **Do not guess or assume a format** — if it hasn't arrived yet, just know
it's coming and its shape is unknown until it does.

### If/when that zip file shows up

Treat it as **much higher-quality reference material** than anything in this document or
already implemented from the Steam-screenshot research. It should **supersede** prior
conclusions wherever the two disagree — it will presumably show real, continuous, in-motion
gameplay from an actual play session across varied moments, not a handful of curated
marketing stills, so it fixes exactly the weaknesses described in the caveat section above.

Do not be confused about what this zip is or why the user is providing it: it is **Mini
Motorways reference material**, supplied specifically to improve on this session's limited
screenshot-based research, in service of refining **flow_grid's own original visual
design** — it is not an asset pack to import or repurpose directly, and flow_grid's
"no copied assets, own palette" rule still applies to anything derived from it.

---

## What this research has already fed into (starting points, not full detail)

Use these as pointers to go look at the actual code/commits/diffs — this doc intentionally
does not re-explain the technical details already captured elsewhere.

- **Car sprite design** — shape, color saturation, drop shadow, and the (subtle, easy to
  overdo) pale window bands. Implemented in `lib/game/components/car_component.dart` and
  `assets/images/normal_vehicles.png`. Went through several iterations this session before
  and after the Mini Motorways research; the two-tone "front cap" false lead and its
  correction are the clearest example of the methodology caveat above in action.
- **Destination-vs-house building size ratio** — Mini Motorways screenshots suggested a
  fairly dramatic destination-vs-house size gap; this project pushed its own destination
  sizing bigger relative to houses accordingly, within the constraint that both are
  single-tile buildings here (unlike Mini Motorways' multi-tile destinations). Implemented
  in `lib/game/components/grid_renderer.dart` (`_drawDestination`, `BuildingProfile`
  render scales) and `lib/models/game_constants.dart` (lot min/max scale).
- **Road-width-to-car-width ratio for two-lane fit** — a research pass on this was
  in-progress or just wrapped up around the time this document was written. Check the git
  log (`git log --oneline`) for the most recent commits touching lane-offset/road-width
  logic in `lib/game/components/car_component.dart`, and check whether this file's sibling
  `session_changes_summary.md` (one directory up from this repo root, i.e. in the
  `flutter-projects` scratchpad parent directory) has been updated to cover it — that
  summary doc was last generated before this particular research pass, so it may not yet
  reflect it.

For full technical detail on any of the above — exact numbers, root causes, before/after —
read the actual commit messages (`git log`) on branch `fix/qa-issues`, and
`session_changes_summary.md` in the scratchpad root (one level up from this repo) for a
narrative walkthrough of the whole branch as of 2026-09-01. This file is orientation only;
those are the sources of truth for what was actually done.
