# Rebuild plan — 2026-08-23, owner-approved

*Written before the owner went away. If a session is interrupted, resume from here.*

## Build these six, in order

| Folder | Version | Games | Star trails |
|---|---|---|---|
| `_work/1.8.2` | `1.8.2+61` | 16 | 2 — Morning Mist, Tide Line |
| `_work/1.9.2` | `1.9.2+62` | 18 | 3 — + Aurora Veil |
| `_work/2.0.2` | `2.0.2+63` | 20 | 4 — + Starfall |
| `_work/2.1.2` | `2.1.2+64` | 22 | 5 — + Petal Fall |
| `_work/2.2.2` | `2.2.2+65` | 23 | 6 — + Constellation |
| `_work/2.3.1` | `2.3.1+66` | 24 | 7 — + Eclipse |

Build numbers 50–60 are already consumed; this set uses **61–66**. Play rejects a reused
`versionCode`.

## Rules

**Trails are cumulative and NOT teased.** A release shows only the star trails earnable in it —
unreleased ones are absent entirely, not greyed out. Showing a player something they cannot
earn is the failure `remember.md` §8 warns about.

**Every folder is the CURRENT tree with future games stashed.** Never the old source. Each
build therefore carries every fix: IAP signature verification, the Zen indicator, the
first-run tour, the reachable analytics opt-out, the unified clear count, the play streak.

**Two things must track the roster per folder, or tests fail:**
1. Seasonal `featuredGameIds` — every id must be live in that build (a stashed id routes the
   player at an unregistered route and crashes; that bug was live in 1.8).
2. The pinned winter test, which asserts winter's exact featured list.

## After building — owner-approved, do it without asking

1. Verify each bundle: entries, ABIs, signature, archive integrity, manifest version.
2. File to `versions/<x.y>/`, write NOTES.
3. Zip each into `Cogniq Versions` as `cogniq(<version>(<code>)).zip`.
4. **Delete** `cogniq(1.8.1(55))` … `cogniq(2.2.1(59))` **and** `cogniq(2.3(60))` — all
   superseded, none ever uploaded.
5. **KEEP** the five originals `cogniq(1.8(50))` … `cogniq(2.2(54))` — untouched, always.
6. Bump `pubspec.yaml` past the highest used number; `flutter clean`.

## Before building
`flutter analyze` → 0 errors. Full `flutter test` → all passing. The four §9f audits clean.
Kill Gradle/Dart daemons between builds — this machine has 7 GB RAM and a previous run OOM'd
in the AOT snapshotter with 3.1 GB held by leftovers (`remember.md` §9h).
