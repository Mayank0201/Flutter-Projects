# Monthly Version Issue Checklist

Open this **before** building each month's release. It's not the fix list —
that's `backport.md`. This is the list of things that rot while you wait.

Eight versions, one a month, means the last one ships roughly eight months after
the first. Plenty changes in eight months that has nothing to do with your code.

---

## Assumed schedule

Adjust if you slip a month — the point is the calendar, not the exact dates.

| Month | Version | Build | Shipped? | Notes |
|---|---|---|---|---|
| Aug 2026 | 1.8 | 69 | | |
| Sep 2026 | 1.9 | 70 | | |
| Oct 2026 | 2.0 | 71 | | |
| Nov 2026 | 2.1 | 72 | | |
| Dec 2026 | 2.2 | 73 | | |
| Jan 2027 | 2.3 | 74 | | |
| Feb 2027 | 2.4 | 75 | | |
| Mar 2027 | 2.5 | 76 | | |

---

## The monthly routine

1. Read last month's Play Console **crash reports and reviews**. Anything real goes
   into this month's version before it ships.
2. Check **Android vitals** — crash rate and ANR rate. If either is near the bad-behaviour
   threshold, fix that before shipping new content.
3. `git checkout` this month's branch.
4. Run `./verify_cogniq_fixes.sh <that version>` — must be green.
5. Check the three rot items below.
6. `flutter analyze`, then build.
7. Smoke test: app launches, daily challenge runs, and **the game this version unstashes**.
8. Upload to internal testing first. Then production.
9. Fill in this file's schedule table and the toolchain log.

---

## Rot item 1 — targetSdk deadline

> **Checked Aug 2026: no action needed.**
> `cogniq/android/app/build.gradle.kts` uses `targetSdk = flutter.targetSdkVersion`,
> so the level comes from the Flutter you build with, not from the code.
> **Flutter 3.41 gives compileSdk 36 / targetSdk 36 / minSdk 24.**
> API 36 is Android 16, which meets the Aug 2026 requirement — so every version you
> rebuild on Flutter 3.41 is compliant automatically, including 1.8.
> Nothing to bump, nothing to propagate.
>
> Side effect: Flutter raised minSdk 21 → 24 (in 3.35). Rebuilding an older version
> drops Android 5.0/5.1 support. Play warns about reduced device reach on upload.
> Expected — not a problem.
>
> The procedure below is kept for the **next** deadline (Aug 2027) or if you are ever
> forced off Flutter 3.41. Re-check the required level in Play Console each month anyway;
> it takes ten seconds.

Google Play raises the minimum `targetSdk` for updates once a year, with an
**August 31 deadline**. After it passes, existing apps stay published but you
**cannot ship updates** until you meet the new target.

**Today is late August 2026.** That deadline is days away, not months.
I earlier told you this would land around month six — that was wrong on this calendar.
It lands between 1.8 and 1.9.

**Do now, before 1.8 ships:**

- Play Console → your app → check the current target API requirement
- compare against `android/app/build.gradle` → `targetSdkVersion` / `targetSdk`
- if 1.8 already meets it, ship 1.8 and plan the bump for 1.9 in September
- if it doesn't, bump before shipping anything

A targetSdk bump is rarely one line. It usually drags dependency and Gradle/AGP
updates with it, and those break things. Budget a full month for whichever version
crosses it, and re-test every game after — not just the one that version unstashes.

If you get caught out, Play normally allows an extension request pushing the
deadline to around November. Don't rely on it, but know it exists.

**Check each month:** does this month's version still meet the current requirement?

### How to actually do the bump

Work down this list and **stop as soon as it builds**. Most apps never get past step 2.

**Step 0 — find the two numbers.**

```bash
# what Play requires: Play Console -> your app -> Dashboard / Policy status
# what you have:
grep -rE "targetSdk|compileSdk|minSdk" android/app/build.gradle
```

Flutter templates often read these from `flutter.targetSdkVersion`, which means the
value comes from your Flutter install. If so, you'll see a variable, not a number.

**Step 1 — override the numbers directly.** This is the surgical fix: it raises the
SDK level *without* upgrading Flutter, which is what you want during these eight months.
Replace the `flutter.*` variables with literals in `android/app/build.gradle`:

```gradle
android {
    compileSdk 36          // must be >= targetSdk; use the level Play requires
    defaultConfig {
        targetSdk 36       // the level Play requires
        minSdk 21          // leave alone
    }
}
```

Then `flutter clean && flutter build appbundle`. If it builds, go to step 4.

**Step 2 — if Gradle complains the compileSdk is unknown or unsupported**, your AGP
is too old for that SDK level. Bump, in this order, and rebuild after each:

- AGP version in `android/build.gradle` (or `android/settings.gradle` in newer templates)
- Gradle wrapper in `android/gradle/wrapper/gradle-wrapper.properties`
- JDK — AGP 8.x needs JDK 17. Check with `java -version`.

**Step 3 — if Play rejects the bundle over 16 KB page size**, that's the native-library
requirement, and it's the bad case: it's satisfied by the Flutter *engine*, not by your
code, so it can force a Flutter upgrade — the one thing rot item 2 says to avoid.
If you hit this, upgrade Flutter once, rebuild **all** remaining versions on the new
toolchain, and re-run the verify script on every one. Budget the whole month.

**Step 4 — test for the visual regressions**, which is where a puzzle game actually breaks:

- **edge-to-edge**: recent Android enforces it, so your board may draw under the status
  bar or gesture nav. Check every game screen top and bottom, not just the menu.
- **predictive back**: confirm the back gesture still exits a game the way it did.
- run the whole roster, not only the game this version unstashes.

**Step 5 — re-verify.** `./verify_cogniq_fixes.sh`, then `flutter analyze`, then internal
testing before production.

**Order matters:** do the bump on the *oldest unshipped version* first, confirm it works,
then carry the same gradle changes forward — same reasoning as the fix backport.

### This is a backport change, not a monthly chore

Shipping one release before the deadline protects **only that upload**. It does not
grandfather the app. Every later upload is judged against the requirement in force on
the day you upload it — so 1.9 in October would hit the same wall.

So do the bump **once**, then propagate the gradle change to all eight versions exactly
like the six code fixes. Treat it as change #7 in `backport.md`. After that, every
remaining release already meets the requirement.

The next annual deadline after this one is **August 2027**, and this run ends around
April 2027. **Only one bump crosses the whole schedule.** Do it once and you're clear
through 2.5.

---

## Rot item 2 — toolchain drift

You build each version in a different month, with whatever Flutter is installed
*that* month. Upgrade Flutter in February and the 1.8-era code you rebuild in
March may not compile.

**Rule: do not upgrade Flutter, Gradle, AGP, or the JDK mid-run** unless rot item 1
forces you to. There is no upside during these eight months.

Record what you actually built with, each month:

| Version | Build date | Flutter | Dart | AGP / Gradle | JDK | targetSdk |
|---|---|---|---|---|---|---|
| 1.8 | | | | | | |
| 1.9 | | | | | | |
| 2.0 | | | | | | |
| 2.1 | | | | | | |
| 2.2 | | | | | | |
| 2.3 | | | | | | |
| 2.4 | | | | | | |
| 2.5 | | | | | | |

Fill it from:

```bash
flutter --version
java -version
grep -rE "com.android.tools.build:gradle|agp" android/build.gradle
grep -E "distributionUrl" android/gradle/wrapper/gradle-wrapper.properties
```

If you are ever forced to upgrade, expect to fix build errors in the *older*
versions too, and re-run the verify script afterwards — a fixed-up build is a
changed build.

---

## Rot item 3 — keystore survival

`android/app/upload-keystore.jks` plus its password is a single point of failure
sitting on one laptop for eight months.

- back it up somewhere safe and **not in the repo** — password manager entry, or an
  encrypted archive
- store the password with it; the file alone is useless
- confirm every month that `git ls-files | grep -iE '\.jks$|key\.properties'`
  returns **nothing**

Losing it is survivable — Play App Signing lets you request an upload key reset —
but it costs you a release cycle. Leaking it is worse and is not undoable once pushed.

---

## Build numbers

`versionCode` must increase forever. Once 2.5 (76) is live you can never publish 70.

- always increment, never reuse
- if you need a hotfix between releases, take the next free number and **shift the
  rest of the table up** — don't squeeze it in
- upload order must match build number order, always

---

## Stop and think if

- crash rate jumped after last month's release → fix before shipping new content
- the verify script goes red on a version that was green before → something drifted, find it
- a targetSdk bump broke a game → re-test all of them, not just the one you noticed
- you're tempted to skip internal testing "because it's a small change" → that's how
  1.8.2 sat unshipped for nine builds

---

## Related files

Keep these together — `backport.md` is the entry point and references the rest.

- `backport.md` — what to change, in what order
- `COGNIQ_FIXES_DAILY_TRAIL_GRIDPATH.md` — trail toast, Grid Path, and why daily persistence is *not* a bug
- `CHALLENGE_MODE_MODIFIERS_AND_DESC.md` — per-game start levels, `_isModActive`, description copy
- `3_GAME_FIXES_FOR_1.8.3.md` — earlier game fixes
- `VERIFY_SCRIPT.md` + `verify_cogniq_fixes.sh` — proving it landed in all eight
- this file — what rots while you wait
