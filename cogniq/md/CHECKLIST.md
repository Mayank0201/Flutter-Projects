# Which file do I open? — a map of every `.md` in this project

*Written 2026-08-23. Start here when you come back to this project after a break and cannot
remember where anything lives.*

There are 14 files in `md/` and 4 more next to your zips in `Documents\Cogniq Versions`.
Most of them you will never need. This page says, in one line each, what every file is for
and whether you can trust it.

---

## 🚦 Start here, in this order

**1. `Documents\Cogniq Versions\NOTES.md`** — which zip is which, and which one to upload next.
**2. `Documents\Cogniq Versions\DECISIONS.md`** — the things waiting on *you*, most urgent first.
**3. `Documents\Cogniq Versions\TESTING_BY_VERSION.md`** — what to check before you upload one.

If you only ever read three files, read those three. Everything below is reference.

---

## 📋 Jobs you might want to do — and the file that tells you how

| I want to… | Open | Where in it |
|---|---|---|
| **Turn analytics on** | `md/remember.md` | **§15** — the 3 steps, the trap, and the Play requirements |
| **Fix or change the home-screen widget** | `md/remember.md` | **§14** — how it works, and why it never refreshes on its own |
| **Know what to test before uploading** | `TESTING_BY_VERSION.md` | Part A always, then the one Part B for your bundle |
| **Decide what to build next** | `DECISIONS.md`, then `md/RELEASE_PLAN.md` | Decisions first, plan second |
| **Add a brand-new game** | `md/GAME_WIRING_CHECKLIST.md` | Follow it top to bottom |
| **Pick which game to add** | `md/new_games.md` | Ten ideas, measured and ranked |
| **Avoid repeating an old mistake** | `md/remember.md` | Sections A–E are hard rules |
| **Add a new swipe trail** | `md/trail_ideas.md` | The shipping plan is at the top |

---

## 📁 The files in `md/`

### Read these — they are current and trustworthy

| File | What it is |
|---|---|
| **`remember.md`** ⭐ | **The rulebook.** Hard constraints, verified facts, and every mistake worth not repeating. Sections A–E are rules; **§14 is the widget, §15 is analytics**. Read before writing any code. |
| **`RELEASE_PLAN.md`** ⭐ | The agreed plan from 1.9 through 2.6 — what ships in each version and why. This is the plan of record. |
| **`TESTING_CHECKLIST.md`** | The long-form device-testing list, organised by when a feature was written. For uploading a bundle use `TESTING_BY_VERSION.md` instead; come here for detail. |
| **`GAME_WIRING_CHECKLIST.md`** | Step-by-step for wiring a new game in correctly. Marked VERIFIED — follow it exactly. |
| **`new_games.md`** | Ten new-game ideas, actually measured rather than guessed. Still Water and Tumble came out on top. |
| **`trail_ideas.md`** | Swipe-trail designs and how stars unlock them. The decided plan is the section at the top. |
| **`CHECKLIST.md`** | This file. |

### Reference — big, useful, but only when you need them

| File | What it is |
|---|---|
| **`cogniq_builders_handbook.md`** | 2,238 lines of recipes for modifiers and new games. **Parts of it are stale** — `RELEASE_PLAN.md` §1.6 lists which sections not to follow. Always check there first. |
| **`GAME_BACKLOG_SPEC.md`** | Logic specs for 55 puzzle types nobody has built. An idea bank, not a plan. |
| **`modifier_pool_expansion.md`** | The design behind modifier batch 2. |
| **`POINTS_ECONOMY_SPEC.md`** | How points and hints work as one currency. |

### Do not build from these

| File | Why |
|---|---|
| **`SEASONAL_ROTATION_SPEC.md`** | ❌ Marked **SUPERSEDED** at the top. Kept for history only. |
| **`REBUILD_PLAN.md`** | Finished. It was the instructions for the 2026-08-23 six-bundle rebuild, which is done. History. |

### Two files that exist in both places, on purpose

`DECISIONS.md` and `TESTING_BY_VERSION.md` live **both** in `md/` and next to your zips. They
were synced on 2026-08-23 so the copies are identical.

**If they ever disagree, the `Documents\Cogniq Versions` copy is the real one** — that is where
you edit, and `md/` is the copy that rides along inside each zip so the archive is
self-contained.

---

## 📁 The files next to your zips (`Documents\Cogniq Versions`)

| File | What it is |
|---|---|
| **`NOTES.md`** ⭐ | What each zip is, which to upload and when, and the known daily-challenge issue in weeks 15–30. |
| **`DECISIONS.md`** ⭐ | **The live decisions list.** What is waiting on you, in the order I would do it. |
| **`TESTING_BY_VERSION.md`** ⭐ | Part A (same for all six bundles) + one short Part B per bundle. |
| **`REBUILD_PLAN.md`** | Finished, history only. |

---

## 🧭 Two rules for keeping this sane

**1. `DECISIONS.md` and `TESTING_BY_VERSION.md` exist in two places and are kept in sync.**
Edit the `Documents\Cogniq Versions` copy — that is the live one. The `md/` copy exists so
each zip is self-contained. If they ever disagree, believe Cogniq Versions.

**2. A file that says SUPERSEDED at the top means it.** `SEASONAL_ROTATION_SPEC.md` says so
outright, and parts of the builder's handbook are stale without saying so — which is why
`RELEASE_PLAN.md` §1.6 keeps a list of the handbook sections not to follow. Check that list
before trusting a handbook recipe.

---

## ✅ Still open — the short list

Everything through **2.3 is finished**: 24 games, 7 swipe trails, six bundles built and
verified, purchase receipts signature-checked.

1. **Test `1.8.2(61)` on a phone and upload it** — the only item with users waiting on it.
2. **Set analytics up yourself when you want it** — `remember.md` §15 has the exact steps.
3. **Next release is 2.4** (Orbit + One Stroke) — order confirmed 2026-08-23, kept as planned.
4. **Two small jobs deliberately left undone** — the week 30 Grand Finale, and the widget's
   dead `favorite_game`. Both are written up; neither is urgent, and neither stops a player
   finishing anything.
