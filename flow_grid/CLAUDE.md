# flow_grid

A Mini Motorways-style traffic-flow game built with Flutter + Flame. The player draws
roads between colour-coded houses and destinations; demand builds at each destination
and the run ends when one overflows.

## Commands

Flutter must be on PATH (or set `$env:FLUTTER_ROOT` to the SDK root).

```powershell
.\dev\run.ps1                  # flutter run -d chrome --web-port 9494
.\dev\run.ps1 windows          # desktop run
.\dev\run.ps1 chrome --release # trailing args forward to flutter
.\dev\analyze.ps1              # flutter analyze (keep this at zero issues)
flutter test                   # only the default widget smoke test exists today
```

`dev/_env.ps1` resolves the repo root and the SDK for both wrappers — never hardcode a
user path in `dev/`. `dev/remove_prints.ps1` and `dev/rename_enums.ps1` are spent one-off
migrations kept for reference; they rewrite files in place, so read the diff if you run them.

This project lives inside a multi-project git repo (`D:/Mayank/Flutter-Projects`), so
`git status` shows sibling Flutter projects too. Scope git commands to `flow_grid/`.

## Architecture

`main.dart` mounts a single `GameWidget` wrapping `FlowGridGame`, with seven Flutter
overlays layered on top: `mainMenu`, `mapSelection`, `saveSlot`, `hud`, `weeklyUpgrade`,
`gameOver`, `tutorial`. All UI is plain Flutter widgets; all simulation is Flame.

**`FlowGridGame`** (`lib/game/flow_grid_game.dart`) is the orchestrator and the only place
that owns cross-system state: `GamePhase`, the active `BuildTool`, camera/zoom, the undo
stack, and the `ValueNotifier`s the HUD listens to (score, week, satisfaction, inventory).

Two things about it are easy to miss:

- **The update loop is tick-split, not per-frame.** Traffic/logic runs at 15 Hz,
  congestion at 5 Hz, metrics at 2 Hz, spawn checks at 1 Hz (rates in `GameConstants`).
  Putting new work directly in `update()` runs it at full frame rate — pick a tick bucket.
- **The "active region"** is a centred rectangle that grows each week and confines *both*
  spawning and player building; camera zoom is derived from its size, so changing the
  region changes the framing.

### Systems (`lib/game/`)

| File | Responsibility |
|---|---|
| `grid_manager.dart` | The grid of `GridCell`, road graph and edges, demand/overflow per destination, traffic signals, terrain, placement and erase rules |
| `spawn_controller.dart` | Where buildings appear: spawn queue, district DNA, atomic district packages (1 destination + 2 houses) with rollback, entrance/driveway validation |
| `progression_director.dart` | Sole authority for *when* colours unlock and districts expand; it only calls `SpawnController` APIs and never touches road/graph logic |
| `pathfinder.dart` | A* over the road graph, with smart-junction sub-nodes, one-way edges and intersection penalties |
| `district_planner.dart` | District territories and `DistrictProfile` assignment (residential / industrial / commercial / tech) |
| `event_manager.dart`, `emergency_manager.dart` | City events and emergency vehicles |
| `transit_manager.dart` | Bus routes and transit-driven demand relief |
| `save_manager.dart` | Three save slots + per-map high scores in SharedPreferences |
| `map_generator.dart` + `generators/` | Six maps: Zen, Andes, Nile, Arctic, Savanna, Delta |
| `components/grid_renderer.dart` | Chunked (16-tile) cached `Picture` rendering with dirty-chunk invalidation |
| `components/car_component.dart` | Per-car motion along a smoothed `ui.Path`: accel/decel, follow-the-leader, lane offsets, deadlock breaking |

### Conventions

- `GridCell` is immutable — mutate via `copyWith`, then call
  `gridRenderer?.markDirty(x, y)` or the chunk stays stale on screen.
- `GridPosition` carries an optional `side` for smart-junction sub-nodes; its `key`
  getter is what all the `Map<String, ...>` state in `GridManager` is indexed by.
- Gameplay code must not spawn buildings directly — go through
  `SpawnController.requestSpawn`, and let `ProgressionDirector` decide timing.
- Tunables (timings, capacities, speeds, colours, tick rates) belong in
  `models/game_constants.dart`, not inline in the systems.
- Logging is `debugPrint` with a bracketed tag (`[BOOT]`, `[SPAWN]`, `[SYNC]`), gated
  where noisy by `GameConstants.debugInfrastructure`.
- Anything touching the road topology should invalidate the path cache via
  `GridManager.onTopologyChanged`.

## Open work

`notes.txt` is the running backlog. Current items: Andes spawns one oversized mountain
instead of a range; car speed while waiting; traffic lights aren't meaningfully useful;
car jitter; collision/overlap checks; game over should destroy the save (permadeath).
