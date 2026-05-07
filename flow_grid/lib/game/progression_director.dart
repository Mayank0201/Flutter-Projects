import 'package:flow_grid/game/spawn_controller.dart';

/// ProgressionDirector — the SINGLE authority for:
/// - Week timing awareness
/// - Color unlock timing
/// - Older-color district expansion packages
///
/// It does NOT touch road/tunnel/expressway/graph logic.
/// It only decides WHEN to request events, then calls SpawnController APIs.
class ProgressionDirector {
  final SpawnController spawnController;

  // ============================================================
  // STATE
  // ============================================================

  double _elapsedTime = 0;

  // Track which week each color was unlocked
  final Map<int, int> _colorUnlockWeek = {};

  // Retry cooldowns for color unlocks (prevent spam)
  final Map<int, double> _colorRetryCooldowns = {};

  // --- EXPANSION POOLS ---
  /// Colors eligible for expansion but not yet expanded this cycle
  final Set<int> _expansionPool = {};
  /// Colors that have already received their expansion this cycle
  final Set<int> _expandedThisCycle = {};

  // --- PER-WEEK FLAGS ---
  bool _hasUnlockedColorThisWeek = false;
  
  // [FIX] Guaranteed Expansions (Issue 2)
  int _pendingExpansionEvents = 0;
  bool _expansionEventTriggeredThisWeek = false;

  // Track the last week we processed (to detect week transitions)
  int _lastWeek = 0;

  // Expansion retry cooldowns
  final Map<int, double> _expansionRetryCooldowns = {};

  ProgressionDirector(this.spawnController);

  void _log(String msg) {
    spawnController.onLog?.call(msg);
    print(msg);
  }

  // ============================================================
  // RESET (called on new game)
  // ============================================================

  void reset() {
    _elapsedTime = 0;
    _colorUnlockWeek.clear();
    _colorRetryCooldowns.clear();
    _expansionPool.clear();
    _expandedThisCycle.clear();
    _expansionRetryCooldowns.clear();
    _hasUnlockedColorThisWeek = false;
    _expansionEventTriggeredThisWeek = false;
    _pendingExpansionEvents = 0;
    _lastWeek = 0;

    // Color 0 (red) is unlocked at week 1
    _colorUnlockWeek[0] = 1;
  }

  // ============================================================
  // UPDATE (called every frame from FlowGridGame)
  // ============================================================

  void update(int week, double weekProgress, double dt) {
    _elapsedTime += dt;

    // Detect week transition → reset per-week flags
    if (week != _lastWeek) {
      _onWeekChanged(week);
      _lastWeek = week;
    }

    // Track A: New color introduction
    _checkColorUnlocks(week, weekProgress);

    // Track B: Older-color district expansion
    _checkExpansionPackages(week, weekProgress);
  }

  // ============================================================
  // WEEK TRANSITIONS
  // ============================================================

  void _onWeekChanged(int newWeek) {
    _hasUnlockedColorThisWeek = false;
    _expansionEventTriggeredThisWeek = false;
  }

  // Removed _rebuildExpansionPoolIfNeeded as it is now handled in-place for single source of truth

  // ============================================================
  // TRACK A: NEW COLOR INTRODUCTION
  // ============================================================

  void _checkColorUnlocks(int week, double progress) {
    if (_hasUnlockedColorThisWeek) return;

    int targetColorCount = _getTargetColorCount(week, progress);

    if (spawnController.activeColorCount < targetColorCount) {
      final newColorIndex = spawnController.activeColorCount;

      // Retry cooldown check
      final cooldown = _colorRetryCooldowns[newColorIndex] ?? 0;
      if (_elapsedTime < cooldown) return;

      // Attempt to spawn the initial district (1 dest + 2 houses)
      final success = spawnController.spawnInitialPair(newColorIndex);

      if (success) {
        spawnController.activeColorCount++;
        _colorUnlockWeek[newColorIndex] = week;
        _hasUnlockedColorThisWeek = true;
      } else {
        // Set cooldown: 6s before retry
        _colorRetryCooldowns[newColorIndex] = _elapsedTime + 6.0;
      }
    }
  }

  /// Determines how many colors should be active at this point in time.
  int _getTargetColorCount(int week, double progress) {
    if (week == 1) {
      // Week 1: Start with 1 (red), unlock blue at ~60%
      return (progress >= 0.6) ? 2 : 1;
    }

    // Week 2+: New color at ~20% of the week
    // Week 2 → 3 colors, Week 3 → 4, etc.
    int target = week + 1;
    if (target > 6) target = 6;

    // Don't unlock instantly at 0% — wait until 20%
    if (progress < 0.2) target--;

    return target.clamp(1, 6);
  }

  // ============================================================
  // TRACK B: OLDER-COLOR DISTRICT EXPANSION
  // ============================================================

  void _checkExpansionPackages(int week, double progress) {
    // [FIX] Guaranteed Expansions (Issue 2)
    // Every week at 60% progress, we add a new expansion event to the queue.
    if (week >= 2 && progress >= 0.6 && !_expansionEventTriggeredThisWeek) {
      _pendingExpansionEvents++;
      _expansionEventTriggeredThisWeek = true;
      _log('[EXPANSION] Week $week milestone reached. Pending events: $_pendingExpansionEvents');
    }

    if (_pendingExpansionEvents <= 0) return;

    // 1. Identify all currently eligible colors (unlocked and at least 1 week old)
    final eligibleColors = _colorUnlockWeek.entries
        .where((e) => week - e.value >= 1)
        .map((e) => e.key)
        .toList();

    if (eligibleColors.isEmpty) return;

    // 2. Pool Reset Rule: If all eligible have expanded, reset cycle
    // (Note: we check if expandedThisCycle contains all currently eligible colors)
    bool allEligibleExpanded = true;
    for (final c in eligibleColors) {
      if (!_expandedThisCycle.contains(c)) {
        allEligibleExpanded = false;
        break;
      }
    }

    if (allEligibleExpanded) {
      _log('[EXPANSION] Pool Reset: All eligible colors (${eligibleColors.length}) have expanded.');
      _expandedThisCycle.clear();
    }

    // 3. Filter eligible colors to find those that haven't expanded this cycle
    final pool = eligibleColors.where((c) => !_expandedThisCycle.contains(c)).toList();
    if (pool.isEmpty) return;

    // 4. Selection: Pick the oldest eligible color from the pool
    pool.sort((a, b) => (_colorUnlockWeek[a] ?? 999).compareTo(_colorUnlockWeek[b] ?? 999));
    final bestColor = pool.first;

    // 5. Cooldown Check
    final cooldown = _expansionRetryCooldowns[bestColor] ?? 0;
    if (_elapsedTime < cooldown) return;

    _log('[EXPANSION] Eligible: $eligibleColors | Pool: $pool');
    _log('[EXPANSION] Selected color $bestColor');

    // 6. Attempt Expansion
    final success = spawnController.spawnExpansionPackage(bestColor);

    if (success) {
      _expandedThisCycle.add(bestColor);
      _pendingExpansionEvents--;
      _log('[EXPANSION] SUCCESS color $bestColor. Remaining pending: $_pendingExpansionEvents');
      spawnController.escalateDistricts(week);
    } else {
      _log('[EXPANSION] FAILED color $bestColor. Retrying in 10s.');
      _expansionRetryCooldowns[bestColor] = _elapsedTime + 10.0;
    }
  }
}
