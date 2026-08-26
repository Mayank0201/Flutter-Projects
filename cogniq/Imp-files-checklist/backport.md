# backport.md

Backport all three changes to the 8 unshipped bundles, using git as the mechanism.

**This file is the entry point.** It holds the procedure and the progress. Everything else lives in the three files below — open them for the actual code, come back here to tick boxes.

---

## Reference map — open this file for that change

| Change | Open | Section | What's in it |
|---|---|---|---|
| **C** — description copy | `CHALLENGE_MODE_MODIFIERS_AND_DESC.md` | §C *"Description copy must not be endgame-framed"* | the `_modifierBannerText` getter, the 3-surface problem, the copy rules table, the 4 raw-string fixes |
| **A** — start levels | `CHALLENGE_MODE_MODIFIERS_AND_DESC.md` | §A *"Per-game modifier start levels"* | the full `_modifierStartLevel` map (33 ids), `modifierCountFor` ramp, `kMinimalPool`, Masyu, Tables 1-4, the 3 coverage tests |
| **B** — challenge mode | `CHALLENGE_MODE_MODIFIERS_AND_DESC.md` | §B *"Challenge mode must honour every modifier"* | `_isModActive`, the 3 species of hand-rolled gate, the 6 hard-disabled getters with file:line |
| **D** — trail toast | `COGNIQ_FIXES_DAILY_TRAIL_GRIDPATH.md` | §2 *"Trail unlock toast missing on the star path"* | the missing call, the 3 things to get right, the Perfect Day dialog collision |
| **E** — Grid Path | `COGNIQ_FIXES_DAILY_TRAIL_GRIDPATH.md` | §3 *"Grid Path: dead difficulty code"* | the floor arithmetic, the `waypointSparsity` no-op table, the patch, the soak spec |
| **F** — Colour Link + Chimp | `3_GAME_FIXES_FOR_1.8.3.md` | whole file | before/after for both games |
| **G** — In-App Review Prompt | `REVIEW_PROMPT_FIXES.md` | whole file | `in_app_review` package, 5-gate `ReviewPromptManager`, app-open tracker, win hook |

Two cross-file rules worth knowing before you start:

- **E supersedes** the Grid Path section inside `3_GAME_FIXES_FOR_1.8.3.md`. Use `COGNIQ_FIXES…md` §3 — the floor arithmetic there was computed, the older one was reasoned about.
- `COGNIQ_FIXES_DAILY_TRAIL_GRIDPATH.md` §1 says the **daily-persistence issue is not a bug** and needs no change. It is in that file so you don't re-investigate it; it is deliberately **not** in the six changes below.

Also in `CHALLENGE_MODE_MODIFIERS_AND_DESC.md`, not part of the backport but read it once: *"What to change in every future update"* — the three triggers for new games, revealed stashed games, and new modifiers. That's what stops this list growing again.

---

## Scope — which bundles, exactly

You have **13 zips**. Only 8 are in scope.

**IN — the unshipped ladder (8 bundles, codes 61-68).** These will all actually be uploaded, so a fix must exist in every one of them or it reappears as a regression on the way up:

`1.8.2(61)` · `(62)` · `(63)` · `(64)` · `(65)` · `2.3.1(66)` · `2.4(67)` · `2.5(68)`

**OUT — the 5 originals (codes 50-54).** `1.8(50)` … `2.2(54)`. These are **superseded** by the drip-feed rebuilds above — the 61-68 ladder already contains everything they do. They are kept as history only and will never be uploaded again, so backporting into them is wasted work.

> **So "1.8 to 2.5" means 1.8.**2**(61) to 2.5(68), not 1.8(50).** If you decide you do want the originals patched too, that is 13 bundles, not 8 — say so before starting, because it changes the build time by roughly half a day.

---

## 0. Before the first push — read this once

Add to `.gitignore` **before** any commit:

```
android/app/upload-keystore.jks
android/key.properties
build/
.dart_tool/
```

The keystore is in every zip. If it lands in a public repo, anyone can sign builds as you, and Play will not rotate an upload key without support intervention. Check with `git status` before the first `git add`, and if it ever gets committed, the history has to be rewritten — not just deleted in a later commit.

---

## 1. Set up: one branch per version

Push oldest first, each version as its own branch off an empty root:

```bash
git checkout --orphan v1.8.2 && git add -A && git commit -m "1.8.2+61 as shipped"
# then for each later version, in order: wipe worktree, copy that version's tree in, commit on a new branch
```

Eight branches: `v1.8.2` … `v2.5`. Nothing depends on anything else, so a bad branch can be redone alone.

---

## 2. Fix the oldest, then patch forward

This is why git is worth the setup — you write the change **once**.

```bash
git checkout v1.8.2
#  ... apply C, then A, then B (see step 3) ...
git commit -am "backport: modifier start levels, challenge mode, copy"
git format-patch -1 -o ../patches      # -> ../patches/0001-backport-....patch
```

Then for each of the other seven branches:

```bash
git checkout v1.9 && git apply --3way ../patches/0001-backport-*.patch
```

Conflicts appear only in files that changed between versions — mostly `game_info.dart` and any screen touched by a later feature. Resolve, commit, move on. **Expect real conflicts on `v2.4` and `v2.5`** (Orbit, One Stroke, Skyscrapers added screens the patch doesn't know about).

---

## 3. The complete change list — all 6, not just 3

Every branch needs **all six** of these. The first three are the big ones; the last three are small and easy to forget precisely because they are small.

| | Change | From | Size |
|---|---|---|---|
| C | Description copy — banner + ~70 strings | `CHALLENGE_MODE…md` §C | large |
| A | Per-game modifier start levels | `CHALLENGE_MODE…md` §A | medium |
| B | `_isModActive` in every screen | `CHALLENGE_MODE…md` §B | 27 files |
| D | **Trail unlock toast on the star path** | `COGNIQ_FIXES…md` §2 | 1 call |
| E | **Grid Path floor + `waypointSparsity` no-op** | `COGNIQ_FIXES…md` §3 | ~6 lines |
| F | **Colour Link curve + Chimp cliff** | `3_GAME_FIXES_FOR_1.8.3.md` | ~2 blocks |
| G | **In-App Review Prompt (5 gates)** | `REVIEW_PROMPT_FIXES.md` | 1 package, 1 helper, 2 call sites |

Notes on the small three:

- **D** — confirm the call site first; it was inferred, not read. Watch the case where the trail unlocks on your third daily and collides with the Perfect Day dialog.
- **E** — section 3 of `COGNIQ_FIXES…md` **supersedes** the Grid Path part of the 1.8.3 md. Use the newer one. Soak the generator before shipping.
- **F** — for Chimp, **playtest levels 25-29 before touching either side.** If they're unwinnable, fix the level table, not the post-30 band. And check whether your version already caps the board at 24 — if so this one is already done and you skip it.

### Order of edits inside each branch: C → A → B → D → E → F

**C — description copy.** Pure UI, no game logic.
- add `_dailyModifierName` / `_dailyModifierDesc` reads to `_loadPrefs`
- add the `_modifierBannerText` getter; point the banner at it
- fix the 4 raw `'daily_modifier_name'` strings to use `PrefsKeys`
- rewrite the `_getModifierDescription` strings for a first-time reader

**A — start levels.** Add `_modifierStartLevel`, `kNoModifierGames`, `modifierStartLevelRaw`, `modifierCountFor` to `rotation_engine.dart`; wire `modifierCountFor` into `getActiveModifiers`. Add `kMinimalPool` and give Masyu `['fog','timer']`.

**B — challenge mode.** Add `_isModActive` per screen and replace every hand-rolled gate. Last, because it's 27 files and carries the regression risk.

Do C on all eight branches before starting A if you'd rather de-risk further — but the patch-forward trick works best with all three in one commit.

**Leave `skyscrapers` at 30** on `v2.5`. Its generator has a ~5 s tail; starting modifiers at level 5 exposes that to new players.

---

## 4. Build numbers

Highest code already built is **68**. Every rebuild needs a fresh code, ascending in upload order:

| # | Branch | Was | New build | Done |
|---|---|---|---|---|
| 1 | `v1.8.2` | +61 | **+69** | ☐ |
| 2 | | +62 | **+70** | ☐ |
| 3 | | +63 | **+71** | ☐ |
| 4 | | +64 | **+72** | ☐ |
| 5 | | +65 | **+73** | ☐ |
| 6 | `v2.3.1` | +66 | **+74** | ☐ |
| 7 | `v2.4` | +67 | **+75** | ☐ |
| 8 | `v2.5` | +68 | **+76** | ☐ |

Fill in the middle version names from `NOTES.md`. Bump the patch digit of the version *name* too (`1.8.2` → `1.8.3`) so you can tell a rebuilt bundle from the original at a glance.

---

## 5. Per-branch build loop

7–8 GB RAM, so strictly one at a time:

```bash
taskkill //F //IM java.exe //T   2>/dev/null
taskkill //F //IM dart.exe //T   2>/dev/null
flutter clean && flutter pub get
flutter analyze                 # 0 errors
flutter test                    # all green -- per branch, not once
flutter build appbundle --release
python verify_file.py build/app/outputs/bundle/release/app-release.aab
```

`flutter test` on every branch, not just the newest — each version has a different set of active games, so green on `v2.5` says nothing about `v1.8.3`.

**Don't run `flutter clean` if a web test server is up** — it deletes `build/web` and kills the server.

---

## 6. Then zip and record

- zip each branch's tree into `Documents\Cogniq Versions\cogniq(<name>(<code>)).zip`
- keep the originals; the rebuilds are new files, not replacements
- one line per bundle in `NOTES.md`: what changed, new code, date
- **add all four md files to every zip** — this one included

### Keep the four together

The reference map at the top only works if the files it names are actually beside it. Wherever this file goes, those three go too:

```
backport.md                                <- entry point, progress lives here
CHALLENGE_MODE_MODIFIERS_AND_DESC.md       <- A, B, C
COGNIQ_FIXES_DAILY_TRAIL_GRIDPATH.md       <- D, E  (+ daily persistence: no-op)
3_GAME_FIXES_FOR_1.8.3.md                  <- F
```

Copy all four into `Documents\Cogniq Versions\` so they sit next to the zips, and into every rebuilt zip's `md/` folder. A one-line pointer in `CHECKLIST.md` — *"Backporting to old bundles → backport.md"* — costs nothing if you want the belt as well as the braces.

### Progress lives in this file

Tick the table in §4 as each bundle finishes, and the per-bundle boxes at the bottom. Eight bundles × six changes is too much to hold in your head across sessions — if the ticks aren't current, you will redo work or ship a half-patched bundle.

---

## 7. Upload

Upload **+69 first** and let it sit in internal testing before pushing the rest. `1.8.2(61)` has been built and unshipped for nine builds and contains the daily-challenge crash fix — that bundle reaching real users matters more than the whole backport.

---

## Definition of done, per bundle

**Changes:** ☐ C ☐ A ☐ B ☐ D ☐ E ☐ F ☐ G

**Build:** ☐ conflicts resolved · ☐ `flutter analyze` 0 errors · ☐ `flutter test` green · ☐ `.aab` verified · ☐ build number bumped · ☐ zipped with 4 md files · ☐ `NOTES.md` line added

## Definition of done, overall

☐ 8 bundles rebuilt · ☐ played levels 3-15 of two games · ☐ played one full day of dailies · ☐ keystore confirmed absent from git history
