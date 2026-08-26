# CogniQ — In-App Review Prompt

> **Where this file belongs:** `Imp-files-checklist/REVIEW_PROMPT_FIXES.md`
>
> **Read this in conjunction with:**
> - `backport.md` — the A–F change set and the propagation procedure for bundles 62–68
> - `WHAT_SHIPPED_IN_1.8.md` — what actually landed in 1.8 and what did not
> - `VERIFY_SCRIPT.md` + `Imp-files-checklist/verify_cogniq_fixes.sh` — the marker/grep checks
> - `BACKPORT_PARTIAL_FIXES.md`, `RESET_PROGRESS_FIXES.md`, `PATTERN_LOCK_FIXES.md`
>
> ⚠️ **This is a NEW FEATURE, not a bug fix.** Every other doc in this folder
> describes something broken that needed correcting. This one adds something that
> was never there. That distinction matters for `backport.md` — see §8.
>
> ⚠️ **Status: NOT IMPLEMENTED.** Nothing in this file is in the codebase as of
> 1.8.2+61. Do not assume any of it exists.

---

## 1. Why this exists

CogniQ has been live for over a month with **0 ratings**.

Rating count and average feed **two** separate systems:

1. **Play search ranking** — apps with more and better ratings rank higher
2. **Listing conversion** — a page with no ratings converts far worse than one with
   even a handful

It is a compounding loop: more ratings → better rank → more listing views → more
installs → more ratings. With zero ratings the loop never starts, and no amount
of listing work compensates.

Nothing in the app currently asks for a rating. That is the entire problem.

---

## 2. The package

`in_app_review` on pub.dev — the standard Flutter wrapper around Google Play's
In-App Review API.

```yaml
dependencies:
  in_app_review: ^X.Y.Z   # check pub.dev for the current version
```

**Check the current version on pub.dev.** Do not copy a version number from this
document — it will be stale.

**Do not upgrade Flutter, Gradle, AGP or the JDK to accommodate it.** That
constraint from `backport.md` still applies. If the current `in_app_review`
requires a toolchain bump, pin to the newest version that does not.

---

## 3. Constraints of the Play API — read before writing code

These determine the design. Getting them wrong wastes the feature.

| Constraint | Consequence |
|---|---|
| **Google decides whether the sheet appears.** `requestReview()` may silently do nothing. | No callback, no way to detect it. Code must be fire-and-forget. |
| **There is a quota** — a small number of prompts per user per year. | Calling more often does not help. It burns quota. |
| **Incentivising is a policy violation.** | Never offer hints, points or anything else for a rating. |
| **Pre-prompting is against Google's guidance.** | Do not ask "do you like the app?" and only show the sheet to people who say yes. |
| **Does not work in debug or sideloaded builds.** | You cannot test it from a local APK. Internal testing track only. |

That last one causes the most confusion. **If nothing happens on your test build,
that is expected — it is not evidence the code is broken.**

---

## 4. Where to fire it

**Never on app launch.** The user has not yet experienced anything worth rating,
and it is the single most annoying placement.

Fire at a **moment of earned satisfaction**, gated so the user has enough history
to have a real opinion:

- Just **after** a level-completion celebration, not during it — let the win
  animation finish
- Total levels completed across all games **≥ 20**
- App opened on **≥ 3 separate days**
- **≥ 90 days** since the last prompt
- **Never** during a Daily Challenge
- **Never** after a loss, timeout or failed level
- **Never** while `ZenMode.isEnabled` is mid-session — Zen is the "leave me alone"
  mode and interrupting it is exactly wrong

---

## 5. Prefs keys

Add to `lib/utils/prefs_keys.dart`, matching the existing style:

```dart
// Review prompt
static const String reviewPromptLastShown = 'review_prompt_last_shown';
static const String distinctDaysOpened    = 'distinct_days_opened';
static const String lastOpenDate          = 'last_open_date';
```

⚠️ **These must NOT be wiped by any bulk-clear path.** `RESET_PROGRESS_FIXES.md`
documents how `resetAllProgress()` was destroying paid hints via a
`k.startsWith('hints_')` sweep, and why the whole feature was removed. The lesson
generalises: if any bulk-clear is ever reintroduced, these three keys must be on
the exclusion list. Clearing them re-arms the prompt and burns the user's quota.

---

## 6. Implementation

Put the gate wherever the other cross-game progress helpers live — **not** inside
an individual game screen. It is called from many screens and must have one
implementation.

```dart
/// Asks Play to show the in-app review sheet, if now is a good moment.
///
/// Google decides whether the sheet actually appears and gives us no way to
/// find out, so this is fire-and-forget. Never call it on launch, after a
/// loss, or during a Daily Challenge.
// COGNIQ-FIX:review-prompt
static Future<void> maybeRequestReview() async {
  if (ZenMode.isEnabled) return;          // Zen is the "don't interrupt me" mode

  final prefs = await SharedPreferences.getInstance();

  // Enough experience to have an opinion?
  final levelsDone = prefs.getInt(PrefsKeys.globalLevelClearedCount) ?? 0;
  if (levelsDone < 20) return;

  final daysOpened = prefs.getInt(PrefsKeys.distinctDaysOpened) ?? 0;
  if (daysOpened < 3) return;

  // Respect Google's quota - don't burn it more than a few times a year.
  final last = prefs.getInt(PrefsKeys.reviewPromptLastShown) ?? 0;
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  if (last != 0 && nowMs - last < const Duration(days: 90).inMilliseconds) return;

  final review = InAppReview.instance;
  if (!await review.isAvailable()) return;

  // Stamp BEFORE requesting: if the sheet does show, we must not ask again,
  // and we get no callback telling us it did.
  await prefs.setInt(PrefsKeys.reviewPromptLastShown, nowMs);
  await review.requestReview();
}
```

And the day counter, called once at startup:

```dart
/// Counts distinct calendar days the app has been opened.
// COGNIQ-FIX:review-prompt
static Future<void> recordAppOpen() async {
  final prefs = await SharedPreferences.getInstance();
  final today = DateTime.now().toIso8601String().substring(0, 10);   // yyyy-MM-dd
  if (prefs.getString(PrefsKeys.lastOpenDate) == today) return;
  await prefs.setString(PrefsKeys.lastOpenDate, today);
  await prefs.setInt(PrefsKeys.distinctDaysOpened,
      (prefs.getInt(PrefsKeys.distinctDaysOpened) ?? 0) + 1);
}
```

**Verify the key name** `globalLevelClearedCount` against `prefs_keys.dart` before
using it — it exists at line ~66 but confirm it is the total-across-all-games
counter and not a per-mode one. If Zen keeps a separate count
(`zen_level_cleared_count`), the Normal-mode counter is the right one here.

---

## 7. Marker comment

Follow the project convention so the verify script and future backports can find
it:

```dart
// COGNIQ-FIX:review-prompt
```

One on `maybeRequestReview()`, one on `recordAppOpen()`, one at each call site.

---

## 8. Backport — this is NOT part of A–F

`backport.md` tracks six lettered changes, **A through F**, all of them bug fixes
for defects that already exist in bundles 62–68.

This feature is not one of them. Adding it silently to the A–F set would corrupt
the record: a future reader diffing a bundle against `backport.md` would see an
unexplained addition and could not tell whether it was intended.

**Do this instead:**

1. Add a **new lettered entry** to `backport.md` — `G` — described explicitly as
   a feature addition, not a fix
2. Note that G has no "broken before" state, so the usual before/after diff format
   does not apply
3. Propagate to bundles 62–68 using the same procedure as A–F

**Or** decide it ships only in 1.9+ and leave 62–68 without it. That is a
defensible call — it is not a defect, and skipping it does not leave those bundles
broken. What is **not** defensible is shipping it into some bundles without
recording which.

---

## 9. Verify script

Add to `Imp-files-checklist/verify_cogniq_fixes.sh` as a new group.

Remember the two lessons already learned in `VERIFY_SCRIPT.md`:

- **Strip comments before grepping.** The existing `strip_comments()` helper
  exists because documenting a fix by quoting the old line above it made every
  documented fix report itself as still broken.
- **Test the fix, not the cause.** Check 3 originally tested the old cause and
  passed on broken code.

Checks worth adding:

| Check | What it greps for |
|---|---|
| 9.1 | `in_app_review` present in `pubspec.yaml` |
| 9.2 | `COGNIQ-FIX:review-prompt` marker present |
| 9.3 | `requestReview()` is **not** called from `main.dart` or any `initState` — the launch-time misuse |
| 9.4 | The 90-day cooldown constant is present near `reviewPromptLastShown` |
| 9.5 | `reviewPromptLastShown` is set **before** `requestReview()` is awaited |

Then update `VERIFY_SCRIPT.md` to describe the new group, and bump the group count
in the summary line (currently "8 of 8 groups clear").

---

## 10. Testing

**`flutter test`** — the gate itself is testable without the plugin. Write tests
for the branch logic with `SharedPreferences.setMockInitialValues()`:

- returns early below 20 levels
- returns early below 3 distinct days
- returns early inside the 90-day window
- returns early when `ZenMode.isEnabled`
- `recordAppOpen()` increments once per calendar day, not once per call

Mock or inject `InAppReview` so the tests never touch the platform channel.

⚠️ The suite is currently **1028 tests passing**. Adding tests is expected; any
test *failing* is not. If the count drops, something regressed.

**On device:** it does not work in debug or sideloaded builds. Push to an
**internal testing track** and install from Play. Even then Google may choose not
to show the sheet — that is normal and not a bug.

---

## 11. What this does not do

- It does not guarantee a prompt appears. Google decides.
- It does not improve a bad app. If retention is poor, prompting more people just
  surfaces more 1-star ratings faster. **Ship the 1.8 fixes first** — the Colour
  Link crash, the dead Grid Path modifier, the start-level rebalance — so the
  people being prompted are seeing the fixed app.
- It does not replace responding to reviews in Play Console. Do that too.

---

## 12. Checklist

- [ ] 1.8 fixes live on Play first (see `WHAT_SHIPPED_IN_1.8.md`)
- [ ] `in_app_review` added, current version checked on pub.dev
- [ ] No Flutter/Gradle/AGP/JDK upgrade was required
- [ ] Three prefs keys added to `prefs_keys.dart`
- [ ] `maybeRequestReview()` implemented with all five gates
- [ ] `recordAppOpen()` implemented and called once at startup
- [ ] `globalLevelClearedCount` confirmed to be the right counter
- [ ] Timestamp stamped **before** `requestReview()`
- [ ] Zen Mode excluded
- [ ] Not called on launch, after a loss, or in a Daily Challenge
- [ ] `// COGNIQ-FIX:review-prompt` markers added
- [ ] New group added to `verify_cogniq_fixes.sh`
- [ ] `VERIFY_SCRIPT.md` updated, group count bumped
- [ ] Gate logic unit-tested; suite still passes (1028+)
- [ ] `flutter analyze` still 0 errors
- [ ] Decision recorded in `backport.md`: entry G, or 1.9+ only
- [ ] Tested from an internal testing track, not a local APK
