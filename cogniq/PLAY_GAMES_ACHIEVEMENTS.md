# CogniQ — Google Play Games Achievements

> **Where this file belongs:** `Imp-files-checklist/PLAY_GAMES_ACHIEVEMENTS.md`
>
> **Read this in conjunction with:**
> - `backport.md` — the A–F change set and the propagation procedure for 62–68
> - `WHAT_SHIPPED_IN_1.8.md` — what actually landed in 1.8
> - `RESET_PROGRESS_FIXES.md` — §9 covers the Play Console / Data Safety /
>   privacy-policy checklist this feature also touches
> - `REVIEW_PROMPT_FIXES.md` — the other feature-addition doc
> - `VERIFY_SCRIPT.md` + `verify_cogniq_fixes.sh`
>
> ⚠️ **Status: NOT IMPLEMENTED and NOT RECOMMENDED YET.** Read §2 before writing
> any code. This document exists so the decision is made deliberately rather than
> discovered halfway through.

---

## 1. What this is, and what it is not

**CogniQ already has 43 achievements.** They live in
`lib/utils/achievement_manager.dart`, are stored locally in
`SharedPreferences`, work offline, need no account, and are visible on the home
screen ("0 / 43 unlocked").

**Google Play Games Services (PGS) achievements are a completely separate
system.** They are:

- Defined in Play Console, not in your code
- Stored on Google's servers against the player's Google account
- Visible in the Play Games app and on the player's Google profile
- Unlocked by API call, matched to a Console-defined achievement ID

Adding PGS does **not** replace your 43. It means running two achievement systems
side by side, or migrating, and either way the local set stays because PGS is not
available to a signed-out player.

---

## 2. ⚠️ The conflict you need to resolve first

**PGS requires the player to sign in with a Google account.**

That collides directly with what CogniQ currently is, and with how you have been
positioning it:

| Current state | With PGS |
|---|---|
| No accounts, nothing server-side | Google account link required for achievements |
| Data Safety form is minimal | Must declare what PGS collects |
| Privacy policy has no account section | Needs one |
| Works fully offline | Achievements need connectivity to sync |
| "no auth, no backend" is true | No longer entirely true |

Three specific things to check **before** committing:

1. **Data Safety declaration.** Your current form declares Device IDs, Financial
   info and App performance. PGS adds identity/account data. This must be updated
   in Play Console **before** a build using PGS goes live. See
   `RESET_PROGRESS_FIXES.md` §9 for the procedure — the same trap applies: the
   declaration must match what ships.

2. **Privacy policy.** Currently at
   `https://springboot-projects-4m5x.onrender.com/privacy-cogniq.html`, and it
   already needs an edit for the removed reset feature (`RESET_PROGRESS_FIXES.md`
   §9.4). A PGS section would be a second edit. Do them together.

3. **Account deletion requirement.** Play requires apps that let users create
   accounts to offer in-app account deletion. PGS uses the player's *existing*
   Google account rather than creating one, so this most likely does **not**
   apply — **but verify it against current Play policy before shipping.** Do not
   take this document's word for it. Getting it wrong is a policy strike.

---

## 3. Honest cost/benefit

**What you gain**

- A small amount of discoverability — PGS games can surface in the Play Games app
- Achievements persist across devices and reinstalls
- A retention hook for players who care about completionism
- Optional extras once PGS is wired: leaderboards, saved games (cloud sync)

**What it costs**

- PGS configuration in Play Console, an OAuth client, a linked Google Cloud project
- A sign-in flow, plus every failure mode that comes with it
- Two achievement systems to keep in sync, or a migration
- Data Safety and privacy policy updates
- Testing complexity — PGS does not work in debug builds, same as the review prompt
- It weakens the "no accounts, fully local" story that is currently a real
  differentiator

**Recommendation: not yet.**

At 10+ downloads and 0 ratings, the binding constraint is that Play has no signal
to rank you on. PGS achievements do not produce ratings, installs or retention at
this stage — they are a feature for a game that already has players. Your local 43
already cover the retention purpose for free.

**Revisit when:** you have a few hundred installs *and* Play Console retention
data showing people return. At that point PGS cloud-sync (saved games) is
probably more valuable than the achievements themselves, because "my progress is
stuck on one device" is the actual complaint you will start hearing.

---

## 4. If you decide to do it anyway

### 4.1 Play Console setup

```
Play Console
  └─ Grow users
      └─ Play Games Services
          └─ Setup and management
              ├─ Configuration       (create, link app, OAuth client)
              ├─ Achievements        (define each one, get its ID)
              └─ Testers             (add your account, required pre-publish)
```

Order matters:

1. Create a PGS project and link it to `com.mayank.cogniq`
2. Create the OAuth2 client — this requires a linked Google Cloud project and the
   **SHA-1 of your upload/signing key**
3. Define achievements one at a time; each returns an **achievement ID** you paste
   into the code
4. Add yourself to the testers list — PGS will not work for anyone else until the
   configuration is published

⚠️ **The SHA-1 comes from `android/app/upload-keystore.jks`.** That file and
`android/key.properties` **are secrets**. Do not commit them, do not paste their
contents anywhere, and if they ever land in git the history must be **rewritten**,
not patched over. Extract only the SHA-1 fingerprint.

### 4.2 Package

`games_services` on pub.dev is the usual Flutter wrapper. Check its current
version and, importantly, **whether it supports Play Games Services v2** — v1 is
deprecated and v2 changed the sign-in model to be largely automatic.

**Do not upgrade Flutter, Gradle, AGP or the JDK to accommodate it.** That
constraint from `backport.md` still holds. PGS pulls in Play Services
dependencies, so check for Gradle conflicts on a branch before committing to it.

### 4.3 Mapping your existing 43

Do **not** rewrite `achievement_manager.dart` to be PGS-backed. Keep local as the
source of truth and mirror to PGS:

```dart
/// Mirrors a locally-earned achievement up to Play Games, if the player is
/// signed in. Local storage stays the source of truth - PGS is unavailable
/// offline and to signed-out players, so it can never be authoritative.
// COGNIQ-FIX:pgs-achievements
static Future<void> mirrorToPlayGames(String localId) async {
  final pgsId = _pgsIds[localId];
  if (pgsId == null) return;              // not every local one needs a PGS twin
  if (!await GamesServices.isSignedIn) return;
  try {
    await GamesServices.unlock(achievement: Achievement(androidID: pgsId));
  } catch (_) {
    // Never let a PGS failure break the local unlock or the celebration UI.
  }
}
```

**Three rules:**

1. **Local stays authoritative.** PGS is unreachable offline and for signed-out
   players. If PGS becomes the source of truth, achievements break for everyone
   who declines sign-in.
2. **Every PGS call is wrapped and swallowed.** A network failure must never
   block a local unlock or an animation.
3. **Sign-in is optional, always.** A player who declines must lose nothing but
   the PGS mirror. No feature gating.

### 4.4 Which of the 43 to mirror

Do not mirror all 43. Play Console achievements are a curated, public-facing list.
Pick 10–15 that read well on a profile — milestone achievements, not grindy ones.

Mark each one's PGS ID in a single map so there is exactly one place that knows
the mapping.

---

## 5. Backport

Like the review prompt, this is a **feature addition, not a fix**, so it is not
part of the A–F set in `backport.md`.

If it ships, add it as its own lettered entry (**H**, if `REVIEW_PROMPT_FIXES.md`
took G) and note that it has no "broken before" state.

**Strong recommendation: do NOT backport this to 62–68.** Unlike the A–F fixes,
those bundles are not broken without it. Backporting a PGS integration across
seven bundles multiplies the Data Safety and sign-in risk surface for no
correctness benefit. Ship it forward-only, in 1.9 or later.

---

## 6. Verify script

If implemented, add a group to `verify_cogniq_fixes.sh`:

| Check | What it greps for |
|---|---|
| x.1 | `games_services` in `pubspec.yaml` |
| x.2 | `COGNIQ-FIX:pgs-achievements` marker present |
| x.3 | Every `GamesServices.` call sits inside a `try` — no unguarded calls |
| x.4 | `achievement_manager.dart` still writes locally before any PGS call |
| x.5 | No keystore path, SHA-1 or OAuth client ID is hardcoded in `lib/` |

Check x.5 matters most. Remember the `strip_comments()` lesson from
`VERIFY_SCRIPT.md` — grep the code, not the comments describing it.

---

## 7. Testing

- PGS does **not** work in debug or sideloaded builds, same as the review prompt.
  Internal testing track only.
- It will not work at all until the PGS configuration is **published** and your
  account is on the testers list.
- Test the **signed-out** path deliberately: decline sign-in and confirm all 43
  local achievements still unlock, display and persist. That is the path most of
  your players will take.
- Suite is at **1028 tests passing**. Mock `GamesServices` so tests never touch
  the platform channel.

---

## 8. Checklist

**Decide first**

- [ ] Read §2 and §3; confirm this is worth doing *now*
- [ ] Confirmed against current Play policy whether the account-deletion
      requirement applies
- [ ] Accepted that "no accounts, fully local" stops being strictly true

**Play Console**

- [ ] PGS project created and linked to `com.mayank.cogniq`
- [ ] OAuth2 client created (SHA-1 extracted from the keystore — **never commit it**)
- [ ] 10–15 achievements defined; IDs recorded
- [ ] Testers list populated
- [ ] Configuration published

**Compliance — before the build goes live**

- [ ] Data Safety declaration updated
- [ ] Privacy policy updated (bundle with the `RESET_PROGRESS_FIXES.md` §9.4 edit)

**Code**

- [ ] `games_services` added; PGS **v2** support confirmed
- [ ] No Flutter/Gradle/AGP/JDK upgrade required
- [ ] Local storage remains the source of truth
- [ ] Every PGS call wrapped in try/catch and swallowed
- [ ] Signed-out path fully functional
- [ ] `// COGNIQ-FIX:pgs-achievements` markers added
- [ ] Verify-script group added; `VERIFY_SCRIPT.md` updated
- [ ] Suite still passes (1028+); `flutter analyze` still 0 errors
- [ ] `backport.md` entry added, marked forward-only (not backported to 62–68)
- [ ] Tested from an internal testing track, signed in **and** signed out
