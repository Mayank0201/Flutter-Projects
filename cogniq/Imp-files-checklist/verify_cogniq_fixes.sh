#!/usr/bin/env bash
# verify_cogniq_fixes.sh - check the six backported fixes landed in a CogniQ version.
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
# The six fixes, each identified by a marker comment you leave in the code.
# Format:  name|path under lib/ (empty = anywhere)|description
# Rename freely - the script only greps for the string you actually type.
PREFIX="COGNIQ-FIX:"
MARKERS=(
  "trail-toast|utils/hint_manager.dart|trail unlock toast fires on the star-completion path"
  "gridpath-floor|screens/games/grid_path|waypoint floor no longer eats the formula"
  "mod-start-map|utils/rotation_engine.dart|per-game _modifierStartLevel map + accessor"
  "mod-active-helper|screens/games|generic _isModActive in each game screen"
  "mod-getters|screens/games|hard-disabled per-modifier getters removed"
  "mod-desc-copy||modifier description copy rewritten"
)

# ------------------------------------------------------------------ helpers
roster_ids() {   # game ids declared in game_info.dart
  grep -oE "(id|gameId): *'[^']+'" "$1" 2>/dev/null \
    | sed -E "s/.*'([^']+)'.*/\1/" | sort -u
}

map_keys() {     # keys inside the _modifierStartLevel map literal
  awk '/_modifierStartLevel/ {f=1} f {print} f && /^[[:space:]]*\};/ {exit}' "$1" 2>/dev/null \
    | grep -oE "'[A-Za-z0-9_]+' *:" | sed -E "s/'([^']+)'.*/\1/" | sort -u
}

modifier_screens() {   # game screens that actually contain modifier logic
  find "$1" -type f -name '*.dart' 2>/dev/null | sort | while read -r f; do
    if grep -qE 'activeModifiers' "$f" 2>/dev/null; then printf '%s\n' "$f"; fi
  done
}

clean_hits() {   # grep -rn over dart files, minus escape-hatched lines
  grep -rnE "$2" "$1" --include='*.dart' 2>/dev/null | grep -v 'not-a-modifier-gate' || true
}

count_lines() { printf '%s' "$1" | grep -c . || true; }

# ------------------------------------------------------------------ one root
verify_root() {
  root="$1"
  VFAIL=0
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
  head2 "1. Fix markers"
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
         "$lib" --include='*.dart' 2>/dev/null | grep -v 'not-a-modifier-gate' || true)
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
        info "map keys not in this roster (expected - future games): $(printf '%s' "$extra" | tr '\n' ' ')"
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
      grep -q 'RotationEngine.modifierStartLevel' "$f" || printf '%s\n' "${f#"$lib"/}" >> "$TMP/bad_call"
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
      warn "literal modifier checks bypassing the helper:"
      printf '%s\n' "$hits" | indent
    fi
  fi

  # -- 6. things that must NOT have changed --------------------------------
  head2 "6. Deliberate non-changes"
  if grep -rq 'daily_backup_' "$lib" --include='*.dart' 2>/dev/null; then
    pass "daily level-swap backup keys intact (persistence is NOT a bug - COGNIQ_FIXES md, section 1)"
  else
    fail "daily_backup_ keys gone - the daily level-swap may be broken"
  fi

  # -- verdict -------------------------------------------------------------
  if [ "$VFAIL" -eq 0 ]; then
    printf '\n  %sVERSION OK%s  %s\n' "$GRN" "$RST" "$label"
    printf '  %sPASS%s  %s (%s)\n' "$GRN" "$RST" "$label" "$ver" >> "$SUMFILE"
  else
    printf '\n  %s%s FAILURE(S)%s  %s\n' "$RED" "$VFAIL" "$RST" "$label"
    printf '  %sFAIL%s  %s (%s) - %s problem(s)\n' "$RED" "$RST" "$label" "$ver" "$VFAIL" >> "$SUMFILE"
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
