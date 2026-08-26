#!/usr/bin/env bash
# verify_cogniq_fixes.sh - check the backported fixes landed in a CogniQ version.
#
# v2 - covers the original six backport changes (A-F) AND the 8 groups from
#      BACKPORT_PARTIAL_FIXES.md.  Replaces v1; same filename on purpose, so
#      backport.md and VERIFY_SCRIPT.md keep working.
#
# Usage:
#   ./verify_cogniq_fixes.sh <path>...
#     <path> = a cogniq project root (folder holding pubspec.yaml + lib/),
#              OR a parent folder holding several of them (auto-expanded).
#
# Exit 0 = every version passed.  Exit 1 = at least one FAIL.
#
# Escape hatch: if a line legitimately trips a check, append the comment
#     // not-a-modifier-gate
# to that line and the script skips it.
#
# NOTE ON GROUPS 1-8: those checks look for the BROKEN pattern and FAIL when
# they find it.  Against an unfixed 1.8 most will fail - that is correct, it is
# a progress meter.  As you close each group the failures go away.  A group
# whose file does not exist in a given version is skipped with a WARN, not
# failed - later bundles have more games, earlier ones fewer.

set -uo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'
  DIM=$'\033[2m';  BLD=$'\033[1m';  RST=$'\033[0m'
else
  RED=; GRN=; YEL=; DIM=; BLD=; RST=
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
SUMFILE="$TMP/summary"
: > "$SUMFILE"

VFAIL=0
OVERALL=0

pass()  { printf '  %sPASS%s  %s\n' "$GRN" "$RST" "$1"; }
fail()  { printf '  %sFAIL%s  %s\n' "$RED" "$RST" "$1"; VFAIL=$((VFAIL + 1)); }
warn()  { printf '  %sWARN%s  %s\n' "$YEL" "$RST" "$1"; }
info()  { printf '  %sinfo%s  %s\n' "$DIM" "$RST" "$1"; }
head2() { printf '\n%s%s%s\n' "$BLD" "$1" "$RST"; }
ROOTSTRIP=""
indent(){ sed "/^$/d; s|${ROOTSTRIP}/||g; s/^/          /"; }

# ------------------------------------------------------------------ markers
# Format:  name|path under lib/ (empty = anywhere)|description
PREFIX="COGNIQ-FIX:"
MARKERS=(
  "trail-toast|utils/hint_manager.dart|trail unlock toast fires on the star-completion path"
  "gridpath-floor|screens/games/grid_path|waypoint floor no longer eats the formula"
  "mod-start-map|utils/rotation_engine.dart|per-game _modifierStartLevel map + accessor"
  "mod-active-helper|screens/games|generic _isModActive in each game screen"
  "mod-getters|screens/games|hard-disabled per-modifier getters removed"
  "mod-desc-copy||modifier description copy rewritten"
  "review-prompt|utils/review_prompt_manager.dart|in-app review prompt with 5-gate safety"
)

# Markers for the 8 groups. These do not exist yet - add one when you close a
# group, and this section turns from "pending" into "PASS".
NEWMARKERS=(
  "mod-deadeffect|group 2 - modifiers announced but doing nothing"
  "mod-unreachable|group 3 - modifiers that can never be selected"
  "mod-inverted|group 4 - modifiers that do the opposite of their description"
  "curve-regression|group 5 - difficulty running backwards"
  "curve-plateau|group 6 - frozen boards"
  "mod-start-early|group 7 - lowered start levels + unwrapped >= 30 blocks"
)

# ------------------------------------------------------------------ helpers
roster_ids() {
  grep -oE "(id|gameId): *'[^']+'" "$1" 2>/dev/null \
    | sed -E "s/.*'([^']+)'.*/\1/" | sort -u
}

map_keys() {
  awk '/_modifierStartLevel/ {f=1} f {print} f && /^[[:space:]]*\};/ {exit}' "$1" 2>/dev/null \
    | grep -oE "'[A-Za-z0-9_]+' *:" | sed -E "s/'([^']+)'.*/\1/" | sort -u
}

modifier_screens() {
  find "$1" -type f -name '*.dart' 2>/dev/null | sort | while read -r f; do
    if grep -qE 'activeModifiers' "$f" 2>/dev/null; then printf '%s\n' "$f"; fi
  done
}

# Matches in a // comment are not shipping code. Agents routinely quote the old
# broken line above the fix ("Was `x`, which ..."), and without this filter every
# documented fix reports itself as still broken.
strip_comments() { grep -vE ':[0-9]+:[[:space:]]*//' || true; }

clean_hits() {
  grep -rnE "$2" "$1" --include='*.dart' 2>/dev/null     | grep -v 'not-a-modifier-gate' | strip_comments || true
}

count_lines() { printf '%s' "$1" | grep -c . || true; }

gbump() { eval "G${1}_F=\$((G${1}_F + 1))"; }

# bug_in <group> <label> <rel-path-under-lib> <regex> <hint>
# FAIL when the broken pattern is FOUND.
bug_in() {
  local g="$1" label="$2" rel="$3" re="$4" hint="$5"
  local f="$lib/$rel" h
  if [ ! -f "$f" ]; then
    warn "$label - $rel not in this version (skipped)"
    return
  fi
  h=$(grep -nE "$re" "$f" 2>/dev/null | grep -v 'not-a-modifier-gate'       | grep -vE '^[0-9]+:[[:space:]]*//' || true)
  if [ -z "$h" ]; then
    pass "$label"
  else
    fail "$label -- $hint"
    printf '%s\n' "$h" | head -4 | sed "s|^|          $rel:|"
    gbump "$g"
  fi
}

# need_in <group> <label> <rel-path> <regex> <hint>
# FAIL when the required pattern is MISSING.
need_in() {
  local g="$1" label="$2" rel="$3" re="$4" hint="$5"
  local f="$lib/$rel"
  if [ ! -f "$f" ]; then
    warn "$label - $rel not in this version (skipped)"
    return
  fi
  if grep -qE "$re" "$f" 2>/dev/null; then
    pass "$label"
  else
    fail "$label -- $hint"
    gbump "$g"
  fi
}

# count_at_most <group> <label> <rel-path> <regex> <max> <hint>
count_at_most() {
  local g="$1" label="$2" rel="$3" re="$4" max="$5" hint="$6"
  local f="$lib/$rel" n
  if [ ! -f "$f" ]; then
    warn "$label - $rel not in this version (skipped)"
    return
  fi
  n=$(grep -nE "$re" "$f" 2>/dev/null | grep -vE '^[0-9]+:[[:space:]]*//' | grep -c . || true)
  if [ "$n" -le "$max" ]; then
    pass "$label  ($n occurrence(s))"
  else
    fail "$label -- $n occurrences, expected at most $max. $hint"
    gbump "$g"
  fi
}

# ------------------------------------------------------------------ one root
verify_root() {
  root="$1"
  VFAIL=0
  G1_F=0; G2_F=0; G3_F=0; G4_F=0; G5_F=0; G6_F=0; G7_F=0; G8_F=0; G9_F=0
  lib="$root/lib"
  gameinfo="$lib/models/game_info.dart"
  rot="$lib/utils/rotation_engine.dart"
  games="$lib/screens/games"

  ROOTSTRIP="$root"
  label=$(basename "$root")
  ver=$(grep -m1 -E '^version:' "$root/pubspec.yaml" 2>/dev/null | sed 's/version: *//')
  [ -z "$ver" ] && ver="unknown"

  printf '\n%s==== %s%s  %s(pubspec version: %s)%s\n' \
    "$BLD" "$label" "$RST" "$DIM" "$ver" "$RST"

  if [ ! -d "$lib" ]; then
    fail "no lib/ under $root - not a project root"
    printf '  %sFAIL%s  %s (%s) - not a project root\n' "$RED" "$RST" "$label" "$ver" >> "$SUMFILE"
    OVERALL=1
    return
  fi

  # -- 1. markers present --------------------------------------------------
  head2 "1. Fix markers (original changes A-F)"
  for entry in "${MARKERS[@]}"; do
    name=${entry%%|*}
    rest=${entry#*|}
    where=${rest%%|*}
    desc=${rest#*|}
    scope="$lib"
    [ -n "$where" ] && scope="$lib/$where"
    if [ ! -e "$scope" ]; then
      warn "$PREFIX$name - expected location missing: ${where:-lib}"
      continue
    fi
    n=$(grep -rl "$PREFIX$name" "$scope" --include='*.dart' 2>/dev/null | grep -c . || true)
    if [ "$n" -gt 0 ]; then
      pass "$PREFIX$name  ($n file) - $desc"
    else
      fail "$PREFIX$name  NOT FOUND under ${where:-lib} - $desc"
    fi
  done

  # -- 2. old hardcoded level-30 gate gone ---------------------------------
  head2 "2. Old level-30 modifier gate removed"
  hits=$(clean_hits "$lib" '[lL]evel(Index)? *>= *30')
  if [ -z "$hits" ]; then
    pass "no 'levelIndex >= 30' gate anywhere in lib/"
  else
    fail "$(count_lines "$hits") surviving level-30 gate(s):"
    printf '%s\n' "$hits" | indent
  fi

  hits=$(clean_hits "$games" '>= *30')
  if [ -n "$hits" ]; then
    warn "other '>= 30' comparisons in game screens - confirm none is a modifier gate:"
    printf '%s\n' "$hits" | indent
  fi

  # -- 3. description copy -------------------------------------------------
  head2 "3. Description copy"
  hits=$(grep -rniE "(past|after|from|beyond) +(level +)?30|level 30\+|30\+ +levels" \
         "$lib" --include='*.dart' 2>/dev/null | grep -v 'not-a-modifier-gate' | strip_comments || true)
  if [ -z "$hits" ]; then
    pass "no 'past 30 levels' style copy left"
  else
    fail "stale modifier copy still shipping:"
    printf '%s\n' "$hits" | indent
  fi

  # -- 4. start-level map covers the roster --------------------------------
  head2 "4. _modifierStartLevel coverage"
  if [ ! -f "$gameinfo" ]; then
    fail "game_info.dart not found at models/game_info.dart"
  elif [ ! -f "$rot" ]; then
    fail "rotation_engine.dart not found at utils/rotation_engine.dart"
  else
    ids=$(roster_ids "$gameinfo")
    keys=$(map_keys "$rot")
    info "roster: $(count_lines "$ids") game id(s)    map: $(count_lines "$keys") key(s)"
    if [ -z "$keys" ]; then
      fail "could not read a _modifierStartLevel map out of rotation_engine.dart"
    else
      printf '%s\n' "$ids"  > "$TMP/ids"
      printf '%s\n' "$keys" > "$TMP/keys"
      missing=$(comm -23 "$TMP/ids" "$TMP/keys" | grep -v '^$' || true)
      extra=$(comm -13 "$TMP/ids" "$TMP/keys" | grep -v '^$' || true)
      if [ -z "$missing" ]; then
        pass "every game in the roster has a start level"
      else
        fail "roster games missing from the map: $(printf '%s' "$missing" | tr '\n' ' ')"
      fi
      if [ -n "$extra" ]; then
        info "map keys not in this roster (expected - aliases + future games): $(printf '%s' "$extra" | tr '\n' ' ')"
      fi
    fi
  fi

  # -- 5. every modifier screen uses the generic helper --------------------
  head2 "5. Generic _isModActive adoption"
  if [ ! -d "$games" ]; then
    fail "screens/games not found"
  else
    modifier_screens "$games" > "$TMP/screens"
    total=$(grep -c . "$TMP/screens" || true)
    : > "$TMP/bad_helper"
    : > "$TMP/bad_call"
    while read -r f; do
      [ -z "$f" ] && continue
      grep -q 'bool _isModActive' "$f" || printf '%s\n' "${f#"$lib"/}" >> "$TMP/bad_helper"
      # Either route is correct: modifierStartLevel() directly, or hasModifiers()
      # which reads the same map. Only flag a screen that uses neither.
      grep -qE 'RotationEngine\.(modifierStartLevel|hasModifiers)' "$f" \
        || printf '%s\n' "${f#"$lib"/}" >> "$TMP/bad_call"
    done < "$TMP/screens"

    info "$total screen file(s) contain modifier logic"
    if [ ! -s "$TMP/bad_helper" ]; then
      pass "all $total declare bool _isModActive"
    else
      fail "$(grep -c . "$TMP/bad_helper") screen(s) missing the _isModActive helper:"
      indent < "$TMP/bad_helper"
    fi
    if [ ! -s "$TMP/bad_call" ]; then
      pass "all $total read the per-game start level"
    else
      fail "$(grep -c . "$TMP/bad_call") screen(s) not calling RotationEngine.modifierStartLevel:"
      indent < "$TMP/bad_call"
    fi

    hits=$(clean_hits "$games" "activeModifiers\.contains\('")
    if [ -n "$hits" ]; then
      warn "literal modifier checks bypassing the helper ($(count_lines "$hits")) - group 1.4"
    fi
  fi

  # -- 6. things that must NOT have changed --------------------------------
  head2 "6. Deliberate non-changes"
  if grep -rq 'daily_backup_' "$lib" --include='*.dart' 2>/dev/null; then
    pass "daily level-swap backup keys intact (persistence is NOT a bug - COGNIQ_FIXES md, section 1)"
  else
    fail "daily_backup_ keys gone - the daily level-swap may be broken"
  fi

  # -- 7. change F (no marker - must be checked by pattern) ----------------
  head2 "7. Change F - Colour Link curve (has no marker)"
  bug_in 1 "Colour Link old 4-branch curve gone" \
    "screens/games/colour_link/colour_link_screen.dart" \
    '_currentLevel >= 60 && _currentLevel < 80' \
    "the pre-F curve is still here: it drops to 6 colours at 60 and cycles from 80, so difficulty runs backwards. See 3_GAME_FIXES_FOR_1.8.3.md."

  # -- 8. GROUP 1 - backport fixes that stopped short ----------------------
  head2 "8. Group 1 - backport fixes that stopped short"

  bug_in 1 "1.1 trail toast uses a threshold, not exact equality" \
    "utils/hint_manager.dart" 'globalCount == 30' \
    "exact equality with no notified-flag: miss the moment and the toast never fires again. Copy TrailCatalog.checkStarUnlocks - threshold + trail_unlocked_toast_<id> flag."

  bug_in 1 "1.2 Word Hive uses the roster gameId" \
    "screens/games/word_hive/word_hive_screen.dart" "modifierStartLevel\('wordhive'\)" \
    "'wordhive' is not a map key so it falls back to 15, while getActiveModifiers uses 'spellingbee' = 12. Levels 12-14 are half-modified. Change the string to 'spellingbee'."

  # 1.3 - one gameId per screen, used in both places
  if [ -d "$games" ]; then
    : > "$TMP/idmismatch"
    find "$games" -name '*_screen.dart' 2>/dev/null | sort | while read -r f; do
      a=$(grep -oE "modifierStartLevel\('[A-Za-z0-9_]+'\)" "$f" 2>/dev/null \
          | sed -E "s/.*'([^']+)'.*/\1/" | sort -u | head -1)
      b=$(grep -oE "gameId: '[A-Za-z0-9_]+'" "$f" 2>/dev/null \
          | sed -E "s/.*'([^']+)'.*/\1/" | sort -u | head -1)
      if [ -n "$a" ] && [ -n "$b" ] && [ "$a" != "$b" ]; then
        printf '%s: modifierStartLevel(%s) vs gameId: %s\n' "${f#"$games"/}" "$a" "$b" >> "$TMP/idmismatch"
      fi
    done
    if [ ! -s "$TMP/idmismatch" ]; then
      pass "1.3 every screen uses one gameId in both places"
    else
      fail "1.3 $(grep -c . "$TMP/idmismatch") screen(s) use two different gameIds:"
      indent < "$TMP/idmismatch"
      gbump 1
    fi
  fi

  # 1.4 - per-modifier getters that nothing calls
  if [ -d "$games" ]; then
    : > "$TMP/deadget"
    find "$games" -name '*_screen.dart' 2>/dev/null | sort | while read -r f; do
      grep -oE 'bool get (_is[A-Za-z0-9_]+) *=>' "$f" 2>/dev/null \
        | sed -E 's/bool get (_is[A-Za-z0-9_]+) *=>/\1/' | sort -u | while read -r g; do
          [ -z "$g" ] && continue
          n=$(grep -c "\b$g\b" "$f" 2>/dev/null || true)
          [ "$n" -le 1 ] && printf '%s: %s declared but never used\n' "${f#"$games"/}" "$g" >> "$TMP/deadget"
        done
    done
    if [ ! -s "$TMP/deadget" ]; then
      pass "1.4 no unused per-modifier getters"
    else
      fail "1.4 $(grep -c . "$TMP/deadget") getter(s) created by mod-getters and never called:"
      head -8 "$TMP/deadget" | indent
      gbump 1
    fi
  fi

  # 1.6 - change A leftovers
  if grep -rq 'modifierCountFor\|kMinimalPool' "$lib" --include='*.dart' 2>/dev/null; then
    pass "1.6 change A's modifierCountFor / kMinimalPool present"
  else
    warn "1.6 modifierCountFor and kMinimalPool absent - read CHALLENGE_MODE_MODIFIERS_AND_DESC.md section A and decide whether they are still wanted (decision, not a bug)"
  fi

  # -- 9. GROUPS 2-4 - dead, unreachable and inverted modifiers ------------
  head2 "9. Groups 2-4 - dead / unreachable / inverted modifiers"

  # 2.1 Pearl Loop zoom
  mas="$lib/screens/games/masyu/masyu_screen.dart"
  if [ -f "$mas" ]; then
    if grep -q "'zoom'" "$mas" 2>/dev/null \
       && ! grep -qE 'InteractiveViewer|TransformationController' "$mas" 2>/dev/null; then
      fail "2.1 Pearl Loop 'zoom' is in the pool but no zoom implementation exists -- the player is told the grid is magnified and nothing happens. Implement it or drop it from the pool."
      gbump 2
    else
      pass "2.1 Pearl Loop zoom"
    fi
  else
    warn "2.1 masyu_screen.dart not in this version (skipped)"
  fi

  pl="$lib/screens/games/pattern_lock/pattern_lock_screen.dart"
  # 2.2 Pattern Lock boardTransform - fixed by gating consumers on whether the
  # transform is genuinely active, not on the unrelated 'timer' modifier.
  if [ -f "$pl" ]; then
    if grep -q "boardTransform" "$pl" 2>/dev/null && ! grep -qE '_transformApplies|_isBoardTransformActive' "$pl" 2>/dev/null; then
      fail "2.2 Pattern Lock computes _transformType but nothing gates on whether boardTransform is actually active -- in free play the transform is never applied."
      gbump 2
    else
      pass "2.2 Pattern Lock boardTransform"
    fi
  else
    warn "2.2 pattern_lock_screen.dart not in this version (skipped)"
  fi

  count_at_most 2 "2.4 Killer Sudoku clueThinning is not a no-op" \
    "screens/games/killer_sudoku/killer_sudoku_screen.dart" 'numGivens = 0' 1 \
    "the modifier sets numGivens = 0 on levels where the band already set it to 0 (26-49)."

  bug_in 2 "2.5 Grid Path waypointSparsity actually removes waypoints" \
    "screens/games/grid_path/grid_path_screen.dart" 'clamp\(minWaypoints' \
    "the -2 is clamped back to the floor, so on even levels 30-48 it changes nothing - including levels 32 and 38, the only two where it appears alone. Lower the floor for the sparse case, or make base never land exactly on minWaypoints."

  # 3.1 Circuit Guide - pool selected after the set is cleared
  cg="$lib/screens/games/circuit_guide/circuit_guide_screen.dart"
  if [ -f "$cg" ]; then
    lc=$(grep -n '_activeModifiers.clear()' "$cg" 2>/dev/null | head -1 | cut -d: -f1)
    le=$(grep -n 'if (_isEndgame)' "$cg" 2>/dev/null | head -1 | cut -d: -f1)
    if [ -n "$lc" ] && [ -n "$le" ] && [ "$lc" -lt "$le" ]; then
      fail "3.1 Circuit Guide clears _activeModifiers at line $lc, then tests _isEndgame at line $le -- _isEndgame reads that emptied set, so it is always false in free play and the endgame pool is never selected. 4 finished modifiers are unreachable."
      gbump 3
    else
      pass "3.1 Circuit Guide endgame pool reachable"
    fi
  else
    warn "3.1 circuit_guide_screen.dart not in this version (skipped)"
  fi

  # 3.2 Practice sandbox
  pr="$lib/screens/games/practice/practice_screen.dart"
  if [ -f "$pr" ]; then
    n=$(grep -c '_isModActive' "$pr" 2>/dev/null || true)
    if [ "$n" -le 1 ]; then
      warn "3.2 Practice declares _isModActive and never calls it; its 3 pool modifiers do nothing. Dev sandbox, but /practice is wired in main.dart - finish it or unwire the route."
    else
      pass "3.2 Practice sandbox"
    fi
  fi

  bug_in 4 "4.1 Killer Sudoku cageSize is not inverted" \
    "screens/games/killer_sudoku/killer_sudoku_screen.dart" 'maxCageSize = _gridSize == 9' \
    "the modifier says cages get LARGER but sets 5/4, and levels 30-49 already have 5 - so it SHRINKS cages and makes the level easier."

  # -- 10. GROUPS 5-6 - difficulty curve -----------------------------------
  head2 "10. Groups 5-6 - difficulty curve"

  bug_in 5 "5.1 Pattern Lock does not collapse at level 30" \
    "screens/games/pattern_lock/pattern_lock_screen.dart" '5 \+ \(_currentLevel % 3\)' \
    "level 29 traces 17 dots, level 30 drops to 5, then cycles 5/6/7 for fifty levels with no escalation."

  bug_in 5 "5.2 Sudoku has no negative-division clue regression" \
    "screens/games/sudoku/sudoku_screen.dart" '\(\(index - 45\) ~/ 3\)' \
    "for levels 30-44 the dividend is negative and ~/ truncates toward zero, so 25 - (-5) = 30 clues at level 30 - MORE help than level 29."

  bug_in 6 "6.1 Grid Path pre-30 waypoint formulas survive the floor" \
    "screens/games/grid_path/grid_path_screen.dart" '3 \+ \(\(levelIndex - 5\) ~/ 3\)' \
    "formula yields 3,3,3,4,4,4,5,5,5,6 and the floor raises all of it to 6 - levels 5-14 identical. Same for 15-26 at 7, and the daily path 30-39 at 8. Fix as :463-464 was fixed: compute relative to minWaypoints."

  # 6.2 Slitherlink - difficulty ignores level
  sl="$lib/screens/games/slitherlink/slitherlink_logic.dart"
  if [ -f "$sl" ]; then
    body=$(awk '/targetRegionFor/{f=1} f{print} f && /^  }/{exit}' "$sl" 2>/dev/null | tail -n +2)
    if printf '%s' "$body" | grep -q 'level'; then
      pass "6.2 Slitherlink targetRegionFor uses the level"
    else
      fail "6.2 Slitherlink targetRegionFor takes 'level' and never reads it (its doc comment claims it rises with level). With sizeFor capped at level 12, the game stops progressing there entirely."
      gbump 6
    fi
  else
    warn "6.2 slitherlink_logic.dart not in this version (skipped)"
  fi

  need_in 6 "6.3 Odd Color Out delta keeps shrinking past level 35"     "screens/games/odd_color_out/odd_color_out_screen.dart" 'delta < 0\.0(1[0-9]|2[0-9])'     "the post-30 delta must fall to a floor well below 0.035, or levels 35+ all ship the same colour difference."

  count_at_most 6 "6.4a Color Flood has no duplicated colour band" \
    "screens/games/color_flood/color_flood_screen.dart" '_numColors = 7;' 1 \
    "the 60-75 and 75-90 branches are character-for-character identical - 30 flat levels."

  # 6.4b Color Flood obstacles never enabled
  cf="$lib/screens/games/color_flood/color_flood_screen.dart"
  if [ -f "$cf" ]; then
    if grep -q 'hasObstacles' "$cf" 2>/dev/null && ! grep -qE 'hasObstacles *= *true' "$cf" 2>/dev/null; then
      fail "6.4b Color Flood 'hasObstacles' is only ever assigned false, so the obstacle generator (and its level-75 density ramp) can never run. Finish the feature or delete it."
      gbump 6
    else
      pass "6.4b Color Flood obstacles"
    fi
  fi

  count_at_most 6 "6.5 Spectrum has no duplicated board band" \
    "screens/games/spectrum/spectrum_screen.dart" '_rows = 8;' 1 \
    "the 45-60 branch and the trailing else both hardcode 8x8 - 30 flat levels, and a shrink from the 9x7 at levels 25-29."

  # -- 11. GROUP 7 - start levels ------------------------------------------
  head2 "11. Group 7 - modifier start levels"

  # 7.1 the four screens that ignore the map
  for pair in \
    "grid_path/grid_path_screen.dart|Grid Path" \
    "mine_finder/mine_finder_screen.dart|Mine Finder" \
    "star_battle/star_battle_screen.dart|Star Battle" \
    "color_flood/color_flood_screen.dart|Color Flood"
  do
    rel=${pair%%|*}
    nice=${pair#*|}
    f="$games/$rel"
    if [ ! -f "$f" ]; then
      warn "7.1 $nice - not in this version (skipped)"
      continue
    fi
    # A fixed screen gates the pool call on the map - via _modsOn, hasModifiers
    # or modifierStartLevel - within a few lines above it. Proximity to a
    # '>= 30' difficulty branch proves nothing: those branches are meant to stay
    # and often sit right beside the (correct) modifier block.
    cl=$(grep -n 'getActiveModifiers' "$f" 2>/dev/null | head -1 | cut -d: -f1)
    if [ -z "$cl" ]; then
      warn "7.1 $nice - no getActiveModifiers call found (skipped)"
      continue
    fi
    from=$((cl - 8)); [ "$from" -lt 1 ] && from=1
    if sed -n "${from},${cl}p" "$f" 2>/dev/null | grep -qE '_modsOn|hasModifiers|modifierStartLevel'; then
      pass "7.1 $nice gates modifier selection on the start-level map"
    else
      fail "7.1 $nice selects modifiers at line $cl with no start-level gate above it -- lowering its map value may do NOTHING. Gate it on RotationEngine.hasModifiers, as pattern_lock does."
      gbump 7
    fi
  done

  # 7.2 report the current numbers so a human can eyeball them
  if [ -f "$rot" ]; then
    nlow=$(awk '/_modifierStartLevel/{f=1} f{print} f && /^[[:space:]]*\};/{exit}' "$rot" 2>/dev/null \
           | grep -oE ": *[0-9]+" | grep -oE "[0-9]+" | awk '$1<=10' | grep -c . || true)
    ntot=$(map_keys "$rot" | grep -c . || true)
    info "7.2 start-level map: $ntot key(s), $nlow at level 10 or below"
    awk '/_modifierStartLevel/{f=1} f{print} f && /^[[:space:]]*\};/{exit}' "$rot" 2>/dev/null \
      | grep -oE "'[A-Za-z0-9_]+' *: *[0-9]+" | sed 's/^/          /' | head -50
  fi

  # -- 12. GROUP 8 - engine dead code --------------------------------------
  head2 "12. Group 8 - engine and housekeeping dead code"

  # 8.1 smallGrid never read
  if [ -f "$rot" ]; then
    n=$(grep -c 'smallGrid' "$rot" 2>/dev/null || true)
    if [ "$n" -le 2 ]; then
      fail "8.1 'smallGrid' appears $n time(s) in rotation_engine.dart - it is a parameter and a comment, never read. 17 call sites pass it for nothing. This becomes load-bearing the moment start levels drop (group 7)."
      gbump 8
    else
      pass "8.1 smallGrid is used"
    fi

    if grep -q 'k < minActive' "$rot" 2>/dev/null && grep -q 'k.clamp(' "$rot" 2>/dev/null; then
      warn "8.2 'minActive' looks inert - the k.clamp() above makes 'k < minActive' unreachable for every call site. Implement or delete."
    else
      pass "8.2 minActive"
    fi
  fi

  # 8.4 Slitherlink announces nothing
  sls="$lib/screens/games/slitherlink/slitherlink_screen.dart"
  if [ -f "$sls" ]; then
    if grep -q '_getModifierDescription' "$sls" 2>/dev/null; then
      pass "8.4 Slitherlink explains its modifiers"
    else
      warn "8.4 Slitherlink has 4 working modifiers and no _getModifierDescription, chips or banner - the board fogs, zooms and decays with no explanation."
    fi
  fi

  # -- 13. new group markers -----------------------------------------------
  head2 "13. Group markers (add one as you close each group)"
  for entry in "${NEWMARKERS[@]}"; do
    name=${entry%%|*}
    desc=${entry#*|}
    n=$(grep -rl "$PREFIX$name" "$lib" --include='*.dart' 2>/dev/null | grep -c . || true)
    if [ "$n" -gt 0 ]; then
      pass "$PREFIX$name  ($n file) - $desc"
    else
      info "$PREFIX$name  pending - $desc"
    fi
  done

  # -- 14. GROUP 9 - in-app review prompt -----------------------------------
  head2 "14. Group 9 - In-App Review prompt (Change G)"

  # 9.1 in_app_review in pubspec.yaml
  if grep -qE 'in_app_review:' "$root/pubspec.yaml" 2>/dev/null; then
    pass "9.1 in_app_review present in pubspec.yaml"
  else
    fail "9.1 in_app_review missing from pubspec.yaml"
    gbump 9
  fi

  # 9.2 review-prompt marker present
  n=$(grep -rl "$PREFIX"review-prompt "$lib" --include='*.dart' 2>/dev/null | grep -c . || true)
  if [ "$n" -gt 0 ]; then
    pass "9.2 COGNIQ-FIX:review-prompt marker present ($n file(s))"
  else
    fail "9.2 COGNIQ-FIX:review-prompt marker missing"
    gbump 9
  fi

  # 9.3 requestReview() not called from main.dart or any initState
  hits=$(grep -rnE 'requestReview\(' "$lib/main.dart" 2>/dev/null | strip_comments || true)
  if [ -z "$hits" ]; then
    pass "9.3 requestReview() not called on app launch in main.dart"
  else
    fail "9.3 requestReview() called on app launch in main.dart:"
    printf '%s\n' "$hits" | indent
    gbump 9
  fi

  # 9.4 90-day cooldown constant
  rpm="$lib/utils/review_prompt_manager.dart"
  if [ -f "$rpm" ]; then
    if grep -qE 'Duration\(days: *90\)' "$rpm" 2>/dev/null; then
      pass "9.4 90-day cooldown present"
    else
      fail "9.4 90-day cooldown missing from review_prompt_manager.dart"
      gbump 9
    fi

    # 9.5 timestamp set before requestReview
    ts_line=$(grep -nE 'setInt.*reviewPromptLastShown' "$rpm" 2>/dev/null | head -1 | cut -d: -f1)
    req_line=$(grep -nE 'review\.requestReview' "$rpm" 2>/dev/null | head -1 | cut -d: -f1)
    if [ -n "$ts_line" ] && [ -n "$req_line" ] && [ "$ts_line" -lt "$req_line" ]; then
      pass "9.5 reviewPromptLastShown timestamp set before requestReview()"
    else
      fail "9.5 reviewPromptLastShown timestamp must be set before requestReview()"
      gbump 9
    fi
  else
    fail "9.4/9.5 review_prompt_manager.dart not found"
    gbump 9
  fi

  # -- verdict -------------------------------------------------------------
  head2 "Group status"
  gclear=0
  for i in 1 2 3 4 5 6 7 8 9; do
    eval "c=\$G${i}_F"
    if [ "$c" -eq 0 ]; then
      printf '  %sclear%s  group %s\n' "$GRN" "$RST" "$i"
      gclear=$((gclear + 1))
    else
      printf '  %sopen %s  group %s  (%s issue(s))\n' "$RED" "$RST" "$i" "$c"
    fi
  done
  printf '  %s%s of 9 groups clear%s\n' "$BLD" "$gclear" "$RST"

  if [ "$VFAIL" -eq 0 ]; then
    printf '\n  %sVERSION OK%s  %s\n' "$GRN" "$RST" "$label"
    printf '  %sPASS%s  %s (%s) - 9/9 groups clear\n' "$GRN" "$RST" "$label" "$ver" >> "$SUMFILE"
  else
    printf '\n  %s%s FAILURE(S)%s  %s\n' "$RED" "$VFAIL" "$RST" "$label"
    printf '  %sFAIL%s  %s (%s) - %s problem(s), %s/9 groups clear\n' \
      "$RED" "$RST" "$label" "$ver" "$VFAIL" "$gclear" >> "$SUMFILE"
    OVERALL=1
  fi
}

# ------------------------------------------------------------------ main
if [ $# -eq 0 ]; then
  echo "usage: $0 <cogniq-project-root|parent-folder>..." >&2
  exit 2
fi

: > "$TMP/roots"
for arg in "$@"; do
  if [ -f "$arg/pubspec.yaml" ]; then
    printf '%s\n' "$arg" >> "$TMP/roots"
  else
    find "$arg" -maxdepth 3 -name pubspec.yaml -type f 2>/dev/null | sort | while read -r p; do
      dirname "$p" >> "$TMP/roots"
    done
  fi
done

if [ ! -s "$TMP/roots" ]; then
  echo "no pubspec.yaml found under: $*" >&2
  exit 2
fi

nroots=$(grep -c . "$TMP/roots")
while read -r r; do
  [ -n "$r" ] && verify_root "$r"
done < "$TMP/roots"

printf '\n%s==== SUMMARY (%s version(s)) ====%s\n' "$BLD" "$nroots" "$RST"
cat "$SUMFILE"
exit "$OVERALL"
