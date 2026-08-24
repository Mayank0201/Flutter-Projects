# Transferring this project to another machine

Prepared 2026-08-22, refreshed during **2.2** development. The working tree is already
clean — `flutter clean` has run and `build/`, `.dart_tool/` and `android/.gradle` are
deleted, so there is nothing here that shouldn't travel. The folder went 1680 MB → **332 MB**.

---

## 🔒 Read this before you zip

**This folder contains your Play Store signing key.**

| File | What it is |
|---|---|
| `android/app/upload-keystore.jks` | The upload keystore |
| `android/key.properties` | Its passwords, in plain text |

Anyone holding both can sign an upload as you. So:

- **Do not** put the zip in a public place, a shared drive, a Discord/Slack message, or
  any AI/cloud service that keeps uploads.
- Prefer a USB stick, or an encrypted transfer you control.
- If you only need the *source* on the other machine and not the ability to build a
  release, **exclude those two files** and the project still works for development —
  `build.gradle.kts` is null-guarded and falls back to debug signing when they're absent.
- If you ever think the key leaked, Play App Signing lets you request an upload key reset.
  Losing control of it is recoverable; losing the file itself is not, so keep a backup
  somewhere safe regardless.

`android/local.properties` also holds a machine-specific SDK path. Harmless, but it will be
wrong on the other machine — delete it and Flutter regenerates it.

---

## What to zip

**Zip the whole `cogniq` folder.** It is currently **332 MB**, and **321 MB of that is
`versions/`** — six `.aab` files at ~54 MB each. The actual source is ~11 MB.

| Folder | Size | Holds |
|---|---|---|
| `versions/2.2` | 55 MB | `cogniq-2.2.0+54.aab` + NOTES — **newest, NOT uploaded** |
| `versions/2.1` | 54 MB | `cogniq-2.1.0+53.aab` + NOTES — **NOT uploaded** |
| `versions/2.0` | 54 MB | `cogniq-2.0.0+52.aab` + NOTES |
| `versions/1.9` | 54 MB | `cogniq-1.9.0+51.aab` + NOTES |
| `versions/1.8` | 54 MB | `cogniq-1.8.0+50.aab` + NOTES |
| `versions/v1.4` | 53 MB | older bundle, contents never reconstructed |
| `versions/v1.5` | 1 MB | NOTES only |

### Option A — source only (~11 MB)
Exclude `versions/`. Everything needed to develop and build.

🔴 **Read this before excluding `versions/`.**

**Play Console has only ever received `1.8.0+50`.** Everything since is built but not
uploaded, so **four of the six bundles exist nowhere but this folder**:

| Bundle | Recoverable if you delete it? |
|---|---|
| `1.8.0+50` | ✅ yes — it is live on Play, re-downloadable |
| `1.9.0+51` | ❌ **no** |
| `2.0.0+52` | ❌ **no** |
| `2.1.0+53` | ❌ **no** |
| `2.2.0+54` | ❌ **no** — and this is the one you will actually ship |
| `v1.4` | ❌ no (predates the current record entirely) |

A rebuild does **not** reproduce a lost artifact: a fresh `flutter build` of the same source
produces a byte-different bundle, and for `+51`–`+53` the source snapshots no longer exist in
the tree at all.

**In practice `+51`, `+52` and `+53` are archive only** — `+54` supersedes all three, so none
of them will ever be uploaded. They are worth keeping as a record, not as shipping
candidates. If disk is tight, they are the reasonable things to drop; `+54` is not.

**Best if** you're moving to a new dev machine and want it fast.

### Option B — everything (~332 MB)
Includes all six bundles.
**Best if** this is your only copy, or you want rollback targets to hand. **This is the safe
default right now**, because of the 2.1 caveat above.

### Option C — source + only the un-uploaded bundles (~120 MB)
Keep `versions/2.1` and `versions/2.2`, drop the rest. The older bundles are all retrievable from Play Console;
their NOTES.md files are small, so copy those back in if you want the history — they carry
findings that are not recorded anywhere else.

Either way, **do not** re-add `build/`, `.dart_tool/` or `android/.gradle` if they
reappear. They embed absolute paths from this machine — including a username with a space
in it — and produce confusing failures elsewhere. They're regenerated automatically.

---

## On the other machine

```
flutter pub get          # restores .dart_tool
flutter analyze          # expect 0 errors
flutter test             # expect all passing (946 as of 2.3.0+60)
```

Then delete `android/local.properties` if you copied it, and let Flutter recreate it.

⚠️ **If the new machine's path also contains a space** (e.g. another `Lancia-AI Bot` user
folder), you'll keep seeing *"Release app bundle failed to strip debug symbols"* on every
release build. It is cosmetic — the bundle is still valid, and this has been true since
1.8. A path without spaces makes it go away.

---

## Where things are

| Path | What |
|---|---|
| `md/RELEASE_PLAN.md` | **Start here.** The plan of record, 1.9 → 2.6, written to be picked up by someone with no context |
| `md/remember.md` | Hard constraints, verified findings, performance rulebook |
| `md/TESTING_CHECKLIST.md` | What must be checked on a real phone, per release |
| `md/cogniq_builders_handbook.md` | Build spec for new games and modifiers |
| `versions/` | Every shipped bundle, each with a `NOTES.md` |
| `versions/_TEMPLATE_NOTES.md` | Copy this for the next release |

---

## Current state

- **Version:** `pubspec.yaml` at `2.3.0+60`.
- **TWO bundles are built and NEITHER is uploaded** — `versions/2.1/cogniq-2.1.0+53.aab`
  and `versions/2.2/cogniq-2.2.0+54.aab`. See the warning under "What to zip".
- **Tests:** **946 passing** · **Analyzer:** **0 errors**, 46 warnings (all dead code), 252 infos
- **Active games:** **24**
- **Not a git repository.** `versions/` + `NOTES.md` is the entire history. Running
  `git init` on the new machine would be a good moment — and it would let you diff two
  versions when hunting a regression, which the folders alone cannot do.

**Three releases are built but never device-tested** — 1.9, 2.0 and 2.1.
`md/TESTING_CHECKLIST.md` has the full list, newest first. The highest-priority item is still
the daily-challenge crash fix in 1.9, because that bug is **live in the 1.8 build your users
have now**.

`md/TESTING_CHECKLIST.md` also carries a **"long-standing items"** section added in 2.1 —
defects that predate 1.8 and are still present in whatever build you are running. Those are
worth a pass on a real phone regardless of which version you install.

---

## If you are an agent picking this up cold

Read in this order. The first two are the only ones you must read in full.

0. **`md/DECISIONS.md`** — **start here.** Everything currently waiting on an owner
   decision, in the order I would do them, in plain words. Nothing in it is blocked on code.
1. **`md/RELEASE_PLAN.md`** — the plan of record, 1.9 → 2.6, written to be picked up with no
   context. Per-release work orders in §4, and an *outcome* section after each shipped
   release recording what the plan got wrong.
2. **`md/remember.md`** — hard constraints. Violating one of these is a defect, not a style
   choice. The ones that bite most often: §8 (never announce a modifier you do not apply),
   §9b (every new game goes in BOTH test harnesses the same day), §9c (measure the spec
   before building on it), §10b (a fallback board is a lie unless verified).
3. `md/TESTING_CHECKLIST.md` — what must be checked on a real phone, newest first, plus a
   "long-standing items" section for defects that predate 1.8.
4. `md/GAME_WIRING_CHECKLIST.md` — the step-by-step for adding a game.
5. `md/cogniq_builders_handbook.md` — design sketches for unbuilt games. **A sketch, not a
   spec**: every game built from it so far needed defects fixed first, and sections already
   built carry a ⚠️ block recording what was measured.
6. `versions/*/NOTES.md` — per-release history. This project is **not a git repository**, so
   these files plus the `.aab` beside them are the entire record of what changed and why.

**Files that are deliberately dead:** `md/SEASONAL_ROTATION_SPEC.md` (superseded, banner at
the top explains why) and the root `remember.md` (a pointer to `md/remember.md`).

---

## Monthly drip-feed rebuilds (started 2026-08-23)

The owner ships **one release per month**, adding a couple of games each time, rather than
shipping 2.2's full 23-game roster at once. Play Console has only ever received
`1.8.0+50`, so every later bundle in `versions/` is archive, not a shipping candidate.

**How a monthly build is made.** Not by editing the old source zips — those are six releases
of drift apart and would need every fix backported by hand. Instead each build is **the
current, fully-fixed tree with future games switched off** via `isStashed: true` in
`lib/models/game_info.dart`. Every build therefore carries every bug fix, and the game roster
is the only thing that differs.

| Build | Version | Live games | Adds |
|---|---|---|---|
| 1 | `1.8.1+55` | 16 | the original roster, all fixes |
| 2 | `1.9.1+56` | 18 | Kakuro, Sand Sort |
| 3 | `2.0.1+57` | 20 | Light Beam, Hitori |
| 4 | `2.1.1+58` | 22 | Zen Slide, Slitherlink |
| 5 | `2.2.1+59` | 23 | Untangle (+ winter event in season) |

**Two things must be adjusted per roster, or tests fail:**

1. **Seasonal `featuredGameIds`** — every featured id must be a game that is LIVE in that
   build. A stashed id would route the player at an unregistered route and crash, which is
   the bug that was live in 1.8. Trim each event's list to games in that roster.
2. **The pinned winter test** in `test/seasonal_event_manager_test.dart` asserts winter's
   exact featured list. Update the pin to match the trim, and say in a comment that this is a
   drip-feed build. This is the **only** test that may be edited; nothing else.

Working folders live in `Documents\Cogniq Versions\_work\<version>\cogniq`. **The original
`cogniq(x.y(nn)).zip` files are kept** — new zips are added alongside them, never over them.

Each folder is validated before building: `flutter analyze` (0 errors; 58 warnings, all
pre-existing dead code),
`flutter test` (868 passing), and the four audits in `md/remember.md` §9f, plus a
roster-specific check that no seasonal event features a stashed game.

---

## 2.3 — what changed structurally (read before working on this tree)

**2.3 removed 25,248 lines.** Ten never-scheduled stashed games were deleted outright: Word
Guess, Word Ladder, Mahjong Solitaire, Hangman, Reaction Time, Number Memory, Word Builder,
Sequence Memory, Word Climb, Flag Finder. **`kAllGames` now has zero stashed entries** — any
test asserting `stashed.isNotEmpty` will fail, and two did; both were rewritten to assert the
positive property (every offered game is live and routable) rather than the negative one.

**`_kDailyChallengesPlan` still names those deleted ids in 16 slots — this is deliberate.**
The resolver treats an unknown id exactly as it treats a stashed one and substitutes a live
challenge, so deleting the entries changes nothing. Rewriting the plan's slots would move
every existing player's daily challenge. Do not "tidy" them.

**`lib/screens/games/practice/` is NOT dead code.** It looks like it — routed in `main.dart`,
absent from `kAllGames`, nothing navigates to it — and it was proposed for deletion. It is
the owner's practice scaffold and the worked example `md/GAME_WIRING_CHECKLIST.md` is written
around. Owner decision 2026-08-23: keep. See `md/remember.md` §9j.

**Build numbers 55-59 are consumed** by the monthly drip-feed rebuilds in
`Documents\Cogniq Versions`. The main tree therefore jumps to `+60`. Whenever an out-of-band
build takes numbers, advance the main tree past them — Play rejects a reused `versionCode`.
