# CogniQ — Remove the "Clear All Saved Progress" feature

**Put this file in `cogniq/Imp-files-checklist/` alongside `backport.md`.**

**Audience:** an AI coding agent working on CogniQ, or a developer picking this up cold.

**Decision already made by the app owner: the reset feature is being removed, from all 8 bundles.** This document is the instruction for doing that. It is not a request for analysis, and it is not asking you to fix the reset behaviour — read §4 before deciding anything here needs repairing instead of deleting.

---

## 0. How this file fits with the others

This folder holds one continuous piece of work. Read the others before acting on this one.

| File | What it covers |
|---|---|
| `backport.md` | **Entry point.** Procedure and progress for the original six changes **A–F**, across bundles **61–68** |
| `BACKPORT_PARTIAL_FIXES.md` | What actually landed vs what the docs claim, plus **8 groups** of modifier and difficulty-curve issues |
| **this file** | **Removal of the reset feature.** A separate axis from the 8 groups — it touches no modifier or level-generation code |
| `CHALLENGE_MODE_MODIFIERS_AND_DESC.md` | Code for changes A, B, C |
| `COGNIQ_FIXES_DAILY_TRAIL_GRIDPATH.md` | Code for changes D and E, plus the daily-persistence non-bug |
| `3_GAME_FIXES_FOR_1.8.3.md` | Code for change F |
| `verify_cogniq_fixes.sh` | Checks A–F and all 8 groups. Does **not** check this removal — see §6 |
| `VERIFY_SCRIPT.md` | What that script proves and what it does not |
| `Monthly_Version_Issue_checklist.md` | Monthly release routine and the three rot risks |

**Precedence:** `backport.md` wins on procedure. `BACKPORT_PARTIAL_FIXES.md` and this file win on status — both were written from a direct audit of the 1.8 code at commit `5da298c`.

### This is a backport change like any other

The removal must reach **all 8 bundles, version codes 61–68**:

`1.8.2(61)` · `(62)` · `(63)` · `(64)` · `(65)` · `2.3.1(66)` · `2.4(67)` · `2.5(68)`

Do it in 1.8 first, verify, then propagate using the `diff -q` procedure in `backport.md` — one branch per version, oldest first.

A feature removed from one bundle and left in the rest reappears as a regression on the way up the ladder. This one is especially easy to miss: a *missing* button raises no error, throws no exception and fails no test. The only thing that catches it is the grep in §6, run per bundle.

### Same rule as everywhere else

**A documented fix is not an applied fix.** Change E proves it — fully written up, half applied, unnoticed for months. After each bundle, grep to confirm the code is actually gone.

---

## 1. Why it is being removed

The feature is a destructive action with no undo, no backup and no export anywhere in the app. An audit found eight distinct problems in it (§4), one of which **destroys goods the player bought with real money**.

Removing it deletes all eight at once, costs about 60 lines, and ends an ongoing maintenance and propagation burden across 8 bundles.

Players who genuinely want a clean slate still have a route CogniQ does not have to build, test or maintain: **Android Settings → Apps → CogniQ → Storage → Clear data**. Purchases restore from Play afterwards, because everything CogniQ stores is device-local and entitlements live with Google.

The feature can be added back later, built correctly, if players actually ask for it. Today it carries eight bugs to serve a use case with no evidence behind it.

---

## 2. Before you touch the code

The code change is safe on its own. What needs confirming is whether anything **outside** the app promises this feature exists. Full Play Console checklist in §9 — do that first, because if a declaration has to change it is better known before the build than after.

Short version: CogniQ has no user accounts and stores everything locally, so removing this button does not affect any Play data-deletion obligation. The checks in §9 are to catch **copy that promises the feature** — in the store listing, the screenshots, or the privacy policy.

---

## 3. What to remove

Three deletions and one clean-up. **All line numbers below are version 1.8 (commit `5da298c`) and will differ in other bundles — navigate by the patterns, not the numbers.**

### 3.1 — The menu entry

`lib/screens/home_screen.dart`, around **line 3014**:

```dart
_ProfileTile(
  icon: Icons.delete_outline,
  title: 'Clear All Saved Progress',
  titleColor: Colors.redAccent,
  onTap: () => _showResetDialog(context),
),
```

Find it with `grep -n "Clear All Saved Progress"`.

**Remove the whole card, not just the tile.** That `_ProfileTile` is the only child of a `Column` inside a decorated `Container` (starting around line 3006, with `borderRadius` and `AppTheme.cardShadow`). Deleting only the tile leaves an empty rounded card with a shadow floating in the profile screen. Delete the `Container` and its contents, and check the surrounding layout — there may be a `SizedBox` above or below that should go with it.

**This is the most likely mistake in the whole change.** A grep will pass while the screen still has a hole in it.

### 3.2 — The dialog

`lib/screens/home_screen.dart`, **lines 3075–3127**:

```dart
void _showResetDialog(BuildContext context) {
```

The whole method, through its closing brace. Find it with `grep -n "_showResetDialog"` — after 3.1 there should be exactly one hit left, the definition itself.

### 3.3 — The reset logic

`lib/theme/settings_manager.dart`, **lines 103–170**:

```dart
Future<void> resetAllProgress() async {
```

Delete the method **and the doc comment block above it** — the one explaining the enumerated allow-list and why achievements and purchases are kept. It describes behaviour that will no longer exist; leaving it stranded above an unrelated method is worse than deleting it.

There are exactly two references to `resetAllProgress` in the codebase: this definition and the call inside the dialog from 3.2. After both deletions, `grep -rn "resetAllProgress" lib/` must return nothing.

### 3.4 — Two imports become orphaned

In `lib/theme/settings_manager.dart`, `HomeWidget` and `ZenMode` are used **only** inside `resetAllProgress` — 10 and 5 occurrences respectively, all within it. Once the method is gone, both imports are unused.

`PrefsKeys` is **not** orphaned: 8 of its 13 uses are in the deleted method, 5 remain elsewhere in the file. Leave that import alone.

Run `flutter analyze` and remove whatever it reports as `unused_import`. Do not guess — usage may differ in later bundles, so let the analyzer decide per version.

---

## 4. What NOT to do

**4.1 — Do not fix the reset behaviour instead of removing it.** The audit found eight problems here: contradictory dialog copy, unclaimed achievements surviving while unclaimed trails silently vanish, half-reset achievement counters, achievements that can never be re-earned, an active trail that can outlive its own ownership, silent trail re-unlocks, and hints bought with points being destroyed.

**All eight disappear with the feature. None of them need fixing.** If you find yourself writing a patch to `resetAllProgress`, stop — you are working on code that is being deleted.

**4.2 — Do not delete any SharedPreferences keys or `PrefsKeys` entries.** Every key the reset method named is still written and read by the rest of the app. `PrefsKeys` is untouched by this change.

**4.3 — Do not touch the other reset methods.** Similar names, unrelated features, called internally. All of them stay:

- `StreakManager.resetAll()` — `lib/utils/streak_manager.dart:343`
- `SeasonalEventManager.resetProgress()` — `lib/utils/seasonal_event_manager.dart:836`

Neither is reachable from the UI element being removed.

**4.4 — Do not remove the daily backup keys.** `daily_backup_*` in `lib/screens/daily_screen.dart` is how the daily challenge swaps a game's level and restores it afterwards. Intended behaviour, documented in `COGNIQ_FIXES_DAILY_TRAIL_GRIDPATH.md` §1, unrelated to this change.

**4.5 — Do not remove `HomeWidget` calls elsewhere.** They exist throughout the app for the home-screen streak widget. Only the ones inside `resetAllProgress` go.

---

## 5. What this changes for the player

Nothing they can see, beyond one red entry disappearing from the profile screen.

No stored data changes. Nobody's progress, achievements, trails, hints or purchases are affected by shipping this. It is a pure removal of a code path that only ever ran when someone tapped that button.

---

## 6. Verifying it

`verify_cogniq_fixes.sh` does not cover this — it checks changes A–F and the 8 groups. Verify by grep, per bundle:

```bash
# all three must return NOTHING
grep -rn "resetAllProgress"          lib/
grep -rn "_showResetDialog"          lib/
grep -rn "Clear All Saved Progress"  lib/

# must stay at 0 errors, and must report no unused_import
flutter analyze
```

Then on a device, once, on 1.8:

1. Open the profile screen. The red entry is gone **and no empty card is left where it was.**
2. Spacing around the remaining entries looks right.
3. Play a level, earn something, force-quit, relaunch — progress, achievements, trails, hints and points all behave exactly as before.

Step 1's second half is the one that gets missed.

---

## 7. Propagating to bundles 62–68

Per `backport.md`: one branch per version, oldest first.

For each bundle:

1. `diff -q` `home_screen.dart` and `settings_manager.dart` against the fixed 1.8 copies. **Identical → copy the fixed file wholesale.**
2. If they differ, apply the three deletions by pattern (§3), never by line number.
3. Run the three greps in §6 — all must return nothing.
4. `flutter analyze` — **0 errors**, no `unused_import`.
5. Run `verify_cogniq_fixes.sh` as usual for the unrelated checks.

The profile screen gained and lost entries across the ladder, so the surrounding layout in `home_screen.dart` will not be identical in every bundle. **Check the card visually per bundle rather than trusting a clean grep** — a grep proves the code is gone, not that the screen still looks right.

---

## 8. Ground rules

- Work only inside `cogniq`. Do not touch `cinetracker`, `flow_grid`, `pulse`, `weather`.
- Never commit `android/app/upload-keystore.jks` or `android/key.properties`. If either lands in a commit the history must be **rewritten**, not patched over.
- Do not upgrade Flutter, Gradle, AGP or the JDK.
- Preserve every `// COGNIQ-FIX:` and `// not-a-modifier-gate` comment.
- **Never destroy paid goods.** The reason this feature is being deleted rather than repaired is that it was doing exactly that.

---

## 9. Play Console checklist

**Do this once, before shipping the first bundle. It applies to the whole ladder, not per bundle.**

Tick each box as you go. Most will need no action — the point is to have checked, and to have a record that you did.

### 9.1 — Data safety declaration

**Play Console → your app → Policy and programs → App content → Data safety** *(the section may be labelled "Policy" or "App content" depending on the console version).*

Look for the **data deletion** question — worded roughly *"Do you provide a way for users to request that their data is deleted?"*

**What is true for CogniQ:**

- There are **no user accounts.** Nothing is stored server-side. Everything lives in SharedPreferences on the device.
- Google Play's in-app data-deletion requirement applies to apps that **let users create an account**. CogniQ does not, so **the requirement does not apply, and removing this button does not breach it.**
- Uninstalling the app, or Android's Clear data, deletes everything CogniQ has stored. That is a complete deletion path and it does not depend on the button.

**Action:** read what is currently declared. Only change the answer if you had specifically declared an **in-app** deletion control that no longer exists. A URL-based answer, or "No", needs no edit.

#### Checked August 2026 — no action needed on the declaration itself

The declaration as it stands is:

| Section | Declared | Source |
|---|---|---|
| Data **shared** | Device or other IDs | AdMob passes the advertising ID on |
| Data **collected** | Financial info → **Purchase history** | Google Play Billing |
| Data **collected** | App info and performance → **Crash logs, Diagnostics** | the analytics / crash layer |
| Data **collected** | Device or other IDs | AdMob |

Under Financial info, only **Purchase history** is ticked — not user payment info, credit score or other financial info. That is correct: the app never sees card details, Google Play handles the transaction.

**None of these are affected by removing the reset button.** Play's Data safety form covers data collected or shared **off the device**. The reset button only ever wiped **local SharedPreferences** — level numbers, streaks, hint balances, achievement lists — none of which ever left the phone, and none of which is declared here.

The button could not have deleted any declared item even in principle: it had no way to remove a crash log from the analytics backend or a purchase record from Google.

**Therefore:** no change to the data types, no change to the sharing declaration, no change to anything analytics-related, and no resubmission needed on account of this removal.

- [x] Data safety data types — checked Aug 2026, **no action needed**
- [x] Data deletion question — checked Aug 2026, answered **not selected**. Correct and unchanged: CogniQ holds no data on a server, so there is nothing for a user to *request* deletion of. The removal does not affect this answer.

### 9.2 — Store listing copy

**Play Console → Grow users → Store presence → Main store listing.**

Search the **short description** and **full description** for: `reset` · `clear progress` · `start over` · `fresh start` · `wipe`

**Action:** if any of them promise the feature, edit the text. If not, nothing to do.

- [ ] Short description checked
- [ ] Full description checked

### 9.3 — Screenshots and feature graphic

Same page as 9.2.

If any screenshot shows the **profile screen**, check whether the red "Clear All Saved Progress" entry is visible in it. If it is, that screenshot is now out of date and should be retaken after the build.

- [ ] Screenshots checked, retaken if the profile screen is shown

### 9.4 — Privacy policy

**URL: `https://springboot-projects-4m5x.onrender.com/privacy-cogniq.html`**

#### Checked August 2026 — ACTION REQUIRED

Section 3, *"Data Deletion and Control"*, currently promises the feature being removed:

> "You can erase all game progress at any time using the **\"Reset All Progress\"** option in the app settings."

Once the button is gone that sentence is false, and a privacy policy is a public commitment. **This is the only external change the removal actually requires.**

Replace this block:

```html
<ul>
    <li>
        You can erase all game progress at any time using the
        <strong>"Reset All Progress"</strong> option in the app settings.
    </li>

    <li>
        Uninstalling the app will also remove all locally stored game data.
    </li>
</ul>
```

with:

```html
<ul>
    <li>
        You can erase all locally stored game data at any time by clearing the
        app's storage from your device settings
        (<strong>Settings &rarr; Apps &rarr; CogniQ &rarr; Storage &rarr; Clear data</strong>).
    </li>

    <li>
        Uninstalling the app will also remove all locally stored game data.
    </li>

    <li>
        Purchases are held by your Google Play account, not on your device, and
        are restored when you reinstall or sign in again.
    </li>
</ul>
```

Two improvements beyond deleting the false line: it gives users a real deletion path that does not depend on the app, and the third bullet tells them clearing data does not cost them their purchases — true, and worth saying.

**Timing: update the page when the first bundle with the button removed goes live, not before.** Until then the current sentence is still accurate.

- [ ] Privacy policy updated (do this at release, not now)

### 9.5 — Release notes

When you upload the first bundle carrying this change, the "What's new" text does not need to mention the removal. It is not a user-facing loss worth announcing, and calling attention to it invites questions.

Mention it only if 9.2 or 9.4 turned up copy that promised the feature — in which case a player may have been relying on it.

- [ ] Release notes written

### 9.6 — Nothing else changes

For completeness, so you do not go looking:

- **No new app permissions.** The removal takes code away, never adds any.
- **No IAP or monetisation change.** Products, prices and entitlements are untouched — this change actually *stops* hints bought with points from being destroyed.
- **No content rating change.**
- **No target API or compliance impact.** See `Monthly_Version_Issue_checklist.md` for what does affect that.
- **No re-review needed** beyond the normal review every upload gets.

---

## 10. Record of what was checked

Fill this in as you go, so next year you are not re-deriving it.

| Check | Date | Result / action taken |
|---|---|---|
| Data safety — data types | Aug 2026 | No action. Local prefs are not declared data; declaration unaffected |
| Data safety — deletion question | Aug 2026 | "Not selected". Correct, no change — no server-side data to request deletion of |
| Short + full description | | |
| Screenshots | | |
| Privacy policy | Aug 2026 | **Action required.** Section 3 promises "Reset All Progress". Replacement HTML in §9.4. Publish at release |
| Release notes | | |
