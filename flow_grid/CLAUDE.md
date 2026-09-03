# flow_grid

A minimalist traffic-flow puzzle game built with Flutter + Flame. The player draws
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
- **Adjacent road tiles always join** (`GridManager._autoConnectNeighbours`, called
  from `placeRoad`). Edges are no longer limited to cells drawn in the same drag, so a
  road dragged up to a driveway stub connects. Tunnels, bridges, smart junctions,
  express lanes and one-way roads keep their own rules and are skipped.
- **Destinations are 2x2.** Only the anchor cell (the one the driveway touches) is in
  `GridManager.destinations` and owns demand/age/name/driveway state, keyed by its
  `"x,y"`. The other three cells are `GridCell.partOf` cells that just block the tile.
  The block hangs off the entry side (`GridManager.destinationExtent`); use
  `destinationFootprint` / `footprintOf` / `isDestinationFootprintFree` rather than
  hand-rolling offsets, and skip `isDestinationPart` cells when iterating buildings.
- **Drag input** seeds the path with the tile under the initial press
  (`_seedDragPathFromPressStart`), because the 24 px drag threshold otherwise skips it,
  and the weekly reward popup commits any in-progress drag before pausing.
- Decorative layers (week tint, car trails, parking pulse, maturity aura) are behind
  `GameConstants` presentation flags and are off for the calm look.
- **Visual language is a calm circuit board.** Deep board-ink ground with soft darker
  patches and small resistor-like components on empty tiles (`_drawTrees`, hash-placed,
  chunk layer). Roads are copper traces: muted copper fill, lighter copper edge, straight
  runs with 45-degree chamfered corners, and via pads (copper disc, rim, dark drilled
  centre) at every dead end and junction (`vias` in the road pass). Houses are small
  diamond chips (`_drawDiamondChip`); shops are IC packages with copper pin legs on a
  pavement pad (`_drawIcChip` inside `_drawDestination`), with a white status LED.
  Demand is a row of LEDs (`_drawLed`), overflow a gauge bar above them. Cars are glowing
  dots drawn procedurally (`CarComponent.drawDot`, also used for parked cars); the sprite
  atlas is loaded but no longer drawn. Buildings cast a short soft drop shadow
  (`_drawLongShadow`). New buildings pop in with an ease-out-back scale under a
  ground-coloured veil (`_drawSpawnAnimations`). Keep the road width and the car lane
  offset in step (`CarComponent._maxSafeLaneOffsetMagnitude` reads
  `GameConstants.roadWidth`).
- **Cars park instead of vanishing, and drive to the spot.** A house keeps two cars
  nose-in on a pavement apron in front of its block (`CarComponent.homeSpotFor`,
  slots assigned by `FlowGridGame._freeHomeSlot`; `GridRenderer._drawParkedCars`
  draws the glyph for every slot with no car out). A shop has two bays reached via
  the tongue and an in-lot corridor (`CarComponent.shopRoute` / `stallFor`, all
  measured from the anchor cell in `GameConstants.shop*`). `_rebuildSmoothPath`
  appends these spurs to the smooth path, fades the lane offset to zero over them
  (`_laneFade`), and a departing car pivots in place before it moves
  (`_approachAngle`, timed from the real frame dt because `_updatePosition` gets a
  speed-scaled dt). Never teleport a car to a parking spot.
- Utility glyphs: roundabout = one-road-width ring on the
  `junctionRingRadius` pathing circle with a ground-colour island, signals = red/green lamps per
  approach, bridges = dark tick marks at each shore, tunnels = dashed edges and no
  portal, express lanes = tinned silver band with pale dashes and round white ramp badges.
- **Never name other games in code, comments, docs, the store listing or commit
  messages.** See `changes_required.md` for why. Describe what the game does instead.
  Keep the look its own: no long single-light cast shadows, no ring timers, no map
  pins, no rounded-square blocks, no free-curving rounded-stroke roads. The circuit
  metaphor (traces, vias, chips, LEDs) is the identity; cars stay colour-coded because
  that is how a player reads them.
- Houses spawn at most `GameConstants.homeParkingSlots` cars at a time
  (`FlowGridGame._carsOutFrom`); the timer holds at the threshold until one is home.

## Open work

`notes.txt` is the running backlog. Current items: Andes spawns one oversized mountain
instead of a range; car speed while waiting; traffic lights aren't meaningfully useful;
collision/overlap checks; game over should destroy the save (permadeath). Car jitter
was traced to the door node's non-null `side` triggering the smart-junction exit
bezier on the first path segment (`CarComponent._rebuildSmoothPath`), plus
nearest-neighbour sprite sampling; both are fixed.
