# changes_required.md

**What has to change before flow_grid can ship as a paid game on Google Play.**

Written 2026-09-03. Scope: differentiation from Mini Motorways (Dinosaur Polo Club),
plus the hard Play Store blockers that exist regardless of any IP question.

> **Not legal advice.** I am not a lawyer. This is a summary of publicly documented
> policy text, platform enforcement history, and case outcomes, plus concrete code
> changes. For a paid commercial launch, an hour with an actual IP attorney is cheap
> next to permanent developer-account termination.

---

## TL;DR

| | |
|---|---|
| Will Google proactively remove you? | **Very unlikely.** Google Play has no look-and-feel / trade-dress policy at all, and has refused this exact complaint from Ubisoft, Krafton and PUBG Corp. |
| So is it safe? | **The lawsuit isn't the risk.** The risks are viral backlash (removals in *hours*, no complaint needed), DMCA (removal fast, restoration ~20 days), and — because it's paid — up to **12 months of revenue clawback**. |
| Is the Android gap real? | **Yes, verified.** Mini Motorways has never shipped on Android in any form. |
| Is the gap permanent? | **No.** Mini Metro *is* on Google Play. The studio ships Android when it wants to. |
| Biggest single lever | Make it not squint-distinguishable. Palette + demand glyph did most of that; see Done below. |

---

## Status

### ✅ Done (2026-09-03) — visual differentiation

These are committed in the working tree and visible in the running build.

| # | Change | Was | Now | File |
|---|---|---|---|---|
| 1 | Ground colour | `#2B303B` | `#22302C` | `lib/models/game_constants.dart` |
| 2 | Grid lines | `#232830` | `#1C2724` | `game_constants.dart` |
| 3 | Road fill | `#2C313B` | `#1F2D29` | `game_constants.dart` |
| 4 | Road kerb | `#8C95A8` | `#8CA89E` | `game_constants.dart` |
| 5 | HUD background | `#22262E` | `#1B2321` | `game_constants.dart` |
| 6 | Water | `#34485F` | `#2E4F58` | `game_constants.dart` |
| 7 | Express lane | `#F2B65A` (amber) | `#8E7FD8` (violet) | `game_constants.dart` |
| 8 | Orange district | `#F5A742` | `#E8853C` | `game_constants.dart` |
| 9 | Mountains | blue-grey set | teal-green set | `game_constants.dart` |
| 10 | **Demand glyph** | **teardrop map pin** | **parcel chip** | `lib/game/components/grid_renderer.dart` |
| 11 | Removed "MM"/"Mini Motorways" attributions from palette comments | — | — | `game_constants.dart` |
| 12 | Corrected a factually wrong comment (see below) | — | — | `game_constants.dart` |

**Why these specific ones.** Reference dark-mode ground measures ≈`#2A303E`; ours was
`#2B303B` — within a couple of points per channel, i.e. the same colour side by side.
Their kerb ≈`#8F97A3`; ours was `#8C95A8`. Their orange ≈`#F6A441`; ours was `#F5A742`
— effectively the same swatch. Amber is their **only** UI accent colour, and our
express lane sat right on it. Hue is what moved; value and contrast relationships are
unchanged, so the art direction still works.

**The glyph matters most.** Research identified the teardrop map pin and colour-matched
capsule cars as the *two most specific* identifiers of a Mini Motorways screenshot. The
cars are near-functional here (you read a car's origin by its hue), so they stay. The
pin was a free choice, so it went — replaced with a parcel chip, which also reads more
literally as "a delivery is waiting here."

**Correction #12:** `game_constants.dart` claimed *"Mini Motorways dark mode: roads are
a shade DARKER than the ground."* That is backwards — their dark-mode roads are
**lighter** (`#4E5359` fill on `#2A303E` ground). Only the fill-plus-contrasting-kerb
*relationship* is invariant, and in light-mode maps like Hong Kong and New York the
roads are dark. Our implementation went darker-than-ground, which is a differentiator —
it just came from a wrong premise. Comment now states the design rationale without the
false claim.

---

### 🔴 Hard blockers — Play Store will not accept the build as-is

Independent of any IP question.

1. **Package name is `com.example.flow_grid`.**
   Google Play **rejects `com.example.*` outright.** Set a real reverse-domain id.
   **This is permanent once published — you can never change it for that listing.**
   - `android/app/build.gradle.kts` → `namespace` and `applicationId`
   - Also update the Kotlin/Java source directory path to match.

2. **Release builds are signed with debug keys.**
   `android/app/build.gradle.kts:34-37` still carries the scaffold TODO. Generate an
   upload keystore, wire a real `signingConfig`, and keep the keystore backed up
   somewhere you will not lose it — losing it means you can never update the app.

3. **App label is lowercase `flow_grid`.**
   `android/app/src/main/AndroidManifest.xml` → `android:label`. Set the real display
   name.

4. **No LICENSE file, and the repo is public.**
   `github.com/mayank0201/flutter-projects` returns HTTP 200 to an unauthenticated
   request. Make it private before selling, or at minimum add an explicit
   all-rights-reserved LICENSE.

5. **Play Console requirements not yet addressed:** privacy policy URL, Data safety
   form, content rating questionnaire, target API level, and a one-time $25 developer
   registration fee.

---

### 🟡 Store-listing rules — the part Google actually enforces

Google has no trade-dress policy, but it **does** enforce these, and this is how nearly
every real Play removal happened:

- **Never write "Mini Motorways" in the store listing, description, ASO keywords, or
  marketing.** This is the live tripwire. The Impersonation policy covers *"App titles
  and icons that are so similar to those of existing products or services that users
  may be misled,"* and the Metadata policy covers misleading descriptions. The Flappy
  Bird clone purge was about **the name**, not the game — Apple's rejection read *"We
  found your app name attempts to leverage a popular app."* Renaming fixed it.
- **Don't use "Mini" as a title prefix.** This is exactly what DPC raised with Mini
  Airways. "Flow Grid" is already clean — keep it that way.
- **Don't imply any association with Dinosaur Polo Club.**
- Avoid "like Mini Motorways" in screenshots, trailer copy, or the short description.

---

### 🟢 Recommended before launch

- **Purge the remaining ~60 "Mini Motorways" mentions in `lib/`** (`grid_renderer.dart`,
  `car_component.dart`, `flow_grid_game.dart`, `grid_manager.dart`,
  `spawn_controller.dart`, `CLAUDE.md`). They aren't infringement — comments aren't
  artwork — but they're on a public repo and they frame your intent for you.
- **Stop writing commit messages like `aa00849`** — *"copy the Mini Motorways dark-mode
  look."* You can't easily rewrite public history; just stop adding to it.
- **Delete `assets/images/vehicles.png`.** 414KB, unreferenced by any code, and its
  provenance is unknown to me. Dead weight with an open licensing question.
- **Keep using Outfit.** It's OFL, free commercially, and Mini Motorways uses
  **Helvetica** — so your typography is both licensing-clean and a genuine
  differentiator. 68 call sites already.
- **Consider further UI divergence.** Your HUD is already structurally different (right
  rail + rounded-square tool grid vs. their top-right status + bottom-centre circular
  row) and your accent is blue vs. their amber-only. This is your strongest asset —
  it's the one thing DPC has ever actually asked another developer to change.

---

## The research this is based on

### Platform facts (verified)

- Mini Motorways: **Apple Arcade** (19 Sep 2019), **Steam** (20 Jul 2021), **Nintendo
  Switch** (11 May 2022). That is the complete list.
- **Never on Android** — no Play listing, no Netflix Games, no other channel.
- DPC's own support FAQ: *"At the moment, we don't have any plans for an Android release
  of Mini Motorways."* Reason given is **studio bandwidth, not an Apple contract.**
- **No DPC statement naming an Apple Arcade exclusivity term or end date exists
  publicly.** 2019 FT/TechCrunch reporting on Arcade terms generally says funded devs
  must skip Google Play, with a "few months" exclusivity that explicitly applies to
  **non-mobile** platforms — consistent with MM shipping on Steam and Switch while
  staying off Android. Whether the Android bar is time-limited is **not documented**.
- ⚠️ **Mini Metro *is* on Google Play** (`nz.co.codepoint.minimetro`, paid, published on
  Android by Playdigious, plus Huawei AppGallery). **The studio does not avoid Android
  on principle.** The gap can close.
- ⚠️ `minimotorways.net` falsely claims Android availability and offers an "APK." It is
  an unofficial fan site, not evidence.

### DPC's enforcement history — three cases, zero lawsuits

| Case | Objection | Outcome |
|---|---|---|
| **Mini Subway** (2022) | Near-identical commercial clone on Switch eShop; framed as **trademark** | Off the eShop; who pulled it is undocumented. No litigation. |
| **All Quiet Roads** (2023) | "Superficial similarities," never specified; triggered by defensive legal advice | **Fully retracted + public apology.** Still on Steam, still patched. |
| **Mini Airways** (2024) | **The title and the UI style — explicitly *not* the gameplay** | Dev voluntarily redesigned UI. No takedown, still on Steam. |

Mini Airways devs' account of DPC's email: DPC was *"totally OK with the gameplay,"*
did not ask for a takedown, but said *"the title and the UI style might cause some
confusion."*

**Never found:** any DPC lawsuit or court filing, any GitHub DMCA from DPC, or any
action against a hobby/jam/student/open-source project. Repos titled *"a clone of Mini
Metro"* have sat on GitHub for years untouched.

### Google Play policy — the structural finding

**Google Play has no look-and-feel or trade-dress policy.** The phrases "look and feel,"
"trade dress," "clone," and "copycat" appear on **none** of the relevant policy pages.
There is no complaint channel for it and no reporter standing.

- **Impersonation policy** reaches **titles and icons only** — not art style, palette,
  or in-game UI.
- **Apple is the opposite**: Guideline **4.1 Copycats** explicitly bans *"minor changes
  to another app's name or UI."* That's what they used for the Wordle purge. **You are
  targeting the more permissive store.**
- **Three major publishers were refused**: PUBG Corp → Apple (2018), Ubisoft → Apple
  *and* Google (2020), Krafton → Apple *and* Google (2021). All three had to sue.
  Free Fire was never removed on IP grounds.
- Google's DDA disclaims any monitoring obligation.

### What actually gets games removed from Play

Not gameplay similarity. These:

- **A name leveraging a popular app** — Flappy Bird purge, Feb 2014.
- **Copied assets or store imagery** — Suika Game fakes; Themer (removed 2 Feb 2014 on
  an Apple DMCA over iOS 7 icon art, restored 10 Feb).
- **Impersonation / fraud** — fake Palworld apps.
- **Malware** — Among Us fakes.
- **Viral embarrassment — the one most likely to hit you.** *Unpacking Master*
  (SayGames, Jan 2022) copied Witch Beam's game "from the name to the premise to the
  viewpoint to the art style," hit #1 free on the App Store, and was removed from
  **both stores within hours** — after backlash, with **no complaint filed.** The
  SayGames CEO publicly apologised. The audience for an Android Mini Motorways-alike is
  precisely the audience that recognises Mini Motorways on sight.
- **DMCA sweep** — The Tetris Company DMCA'd ~35 Tetris clones off the Android Market in
  2010 and Google removed them, including one whose dev protested it had *"its own name,
  graphics and sounds… no reference to 'Tetris.'"*

### Why paid specifically raises exposure

**Developer Distribution Agreement §8.2 (Legal Takedowns):** if a paid app is removed on
an infringement allegation, *"You agree to refund to the end user all amounts paid"* for
purchases in the preceding **year**.

**Enforcement Process:** suspensions count as strikes; *"Multiple strikes can result in
the termination of individual and related Google Play Developer accounts."* Termination
is permanent and contagious — *"Any related Google Play developer accounts will also be
permanently suspended,"* and *"Any new account that you try to open will be terminated
as well (without a refund of the developer registration fee)."*
⚠️ Google does **not** publish a strike count; the "three strikes" figure is folklore.

**Asymmetry to internalise:** removal is fast and near-automatic; restoration is slow and
procedural. One documented counter-notice case ran **~20 days offline** on a notice that
was ultimately meritless.

### The case worth knowing

**Tetris Holding v. Xio Interactive** (D.N.J., 30 May 2012). The defendant **drew all its
own art** and argued it had copied only unprotectable game rules. It **lost on both
copyright and trade dress.**

- *"copyright does not protect the idea for a game, its name or title, or the method or
  methods for playing it"* — but the court protected piece styling, colours, field
  dimensions, ghost piece, next-piece preview, line-clear animation.
- Piece colours were held **"arbitrary flourishes"** — non-functional, therefore
  protectable trade dress.
- *"If one has to squint to find distinctions only at a granular level, then the works
  are likely to be substantially similar."*

"I drew my own sprites" was not a defence. Palette choices and a decorative marker glyph
are squarely in the "arbitrary flourishes" category — which is why items 1–10 above were
worth doing.

**Counterweight:** *Voodoo v. Rollic* (Paris, Sept 2020) is the only court-ordered Play
delisting found — and the court held the original **not original enough for copyright**,
granting relief on unfair competition instead.

---

## Sources

Dinosaur Polo Club [support FAQ](https://dinopoloclub.com/support/mini-motorways/) ·
[Mini Metro platforms](https://dinopoloclub.com/games/mini-metro/) ·
[Mini Metro on Google Play](https://play.google.com/store/apps/details?id=nz.co.codepoint.minimetro) ·
[Mini Airways Steam thread](https://steamcommunity.com/app/2289650/discussions/0/4515506448136340257/) ·
[DPC on Mini Airways](https://steamcommunity.com/app/1127500/discussions/0/4356746952211193822/) ·
Play policies: [Impersonation](https://support.google.com/googleplay/android-developer/answer/9888374) ·
[Spam / Repetitive Content](https://support.google.com/googleplay/android-developer/answer/9899034) ·
[Metadata](https://support.google.com/googleplay/android-developer/answer/9898842) ·
[Intellectual Property](https://support.google.com/googleplay/android-developer/answer/9888072) ·
[Enforcement Process](https://support.google.com/googleplay/android-developer/answer/9899234) ·
[Developer Distribution Agreement](https://play.google/developer-distribution-agreement.html) ·
[Apple Review Guidelines 4.1](https://developer.apple.com/app-store/review/guidelines/) ·
[Unpacking Master removal (Kotaku)](https://kotaku.com/unpacking-master-ios-play-store-clone-mobile-gaming-wit-1848414416) ·
[Tetris clone DMCA sweep](https://games.slashdot.org/story/10/05/28/079200/tetris-clones-pulled-from-android-market) ·
[Ubisoft v. Apple/Google](https://kotaku.com/ubisoft-sues-google-and-apple-over-rainbow-six-siege-r-1843493191) ·
[Krafton v. Apple/Google/Garena](https://techcrunch.com/2022/01/13/pubg-mobile-maker-krafton-sues-apple-google-and-rival-game-developer-garena-over-clones/) ·
[Voodoo v. Rollic](https://www.pocketgamer.biz/news/74555/voodoo-wins-court-case-rollic/) ·
[Apple Arcade exclusivity reporting](https://techcrunch.com/2019/04/15/apple-said-to-be-spending-more-than-500m-on-arcade-gaming-subscription-effort)
