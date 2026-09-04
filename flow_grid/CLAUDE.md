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

`dev/run.ps1` also sweeps orphaned `flutter_tools.*` build-scratch folders (older than
15 minutes) out of `%LOCALAPPDATA%\Temp` before launching: killing the dev server
leaves one behind every time and they fill the system drive.
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
  `SpawnController.requestSpawn`, and let `ProgressionDirector` decide timing. A staged
  shop reserves its whole 2x2 footprint plus its driveway; if the spot is built over
  anyway it is re-sited nearby (`_findReplacementDestinationSpot`) or retried, never
  skipped, and `_repairOrphanedColors` re-sites a shop for any colour left with houses
  and no shop. Those tunables live in `SpawnConfig`.
- Tunables (timings, capacities, speeds, colours, tick rates) belong in
  `models/game_constants.dart`, not inline in the systems.
- Logging is `debugPrint` with a bracketed tag (`[BOOT]`, `[SPAWN]`, `[SYNC]`), gated
  where noisy by `GameConstants.debugInfrastructure`.
- Anything touching the road topology should invalidate the path cache via
  `GridManager.onTopologyChanged`.
- **A new road tile adopts only adjacent loose ends** (`GridManager._autoConnectNeighbours`,
  called from `placeRoad`): a neighbour with fewer than two connections of its own, such
  as a driveway stub or the end of another trace. It used to join every adjacent road,
  which silently merged two traces running side by side. To tee into a trace already
  carrying traffic, drag onto it. Tunnels, bridges, smart junctions,
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
- **Shop maturity has to be legible.** At `maturityThresholdWeeks` a shop's demand
  ceiling goes `maxDemand` -> `matureMaxDemand` and its demand ticks get faster
  (`demandAgeScalingRate`, `matureRequestSpeedMultiplier`) -- keep those in step, or
  maturity makes a shop *easier*, which is what happened. On screen its pad grows from
  `lotMinScale` to `lotMaxScale`, the chip fattens on top of that, and the status LED
  turns amber. `placeDestination`/`placeHouse` must clear `destinationAges` and
  `overflowLevels` for the key: a re-sited shop used to inherit the age of whatever
  stood there before. A shop showing no demand LEDs is not broken,
  it is being served faster than its demand timer ticks.
- **The city-reveal vignette paints opaque ground outside the active region**
  (`_drawCityVignette`). Its hole is inflated past the region because a building is
  anchored inside but its block and pad reach ~1.5 tiles beyond the anchor; without the
  inflation a building on the border is painted in half.
- **Visual language is a calm circuit board.** Deep board-ink ground with soft darker
  patches and small signal towers on empty tiles (`_drawTrees`, hash-placed, chunk
  layer). Player-facing text calls roads "paths" and the smart junction a "hub";
  code keeps the road/junction names. Roads are copper traces: muted copper fill, lighter copper edge, straight
  runs with 45-degree chamfered corners, and via pads (copper disc, rim, dark drilled
  centre) at dead ends and 4-way crossings only (`vias` in the road pass) -- never on a
  tee (a field of circles) and never on a hub cell (the pad filled the ring's island and
  the hub read as a solid gear). Houses are small
  diamond chips (`_drawDiamondChip`); shops are IC packages with copper pin legs on a
  pavement pad (`_drawIcChip` inside `_drawDestination`), with a white status LED.
  Demand is a row of LEDs (`_drawLed`), overflow a gauge bar above them. Vehicles are
  hover drones: a domed disc in the house colour with a hover shadow and faint glow, drawn
  procedurally (`CarComponent.drawDrone`, also used for parked drones); the component's
  `angle` is always 0 so the sprite stays upright through turns. Player-facing text says "drones"; code keeps the `car` names. The
  sprite atlas is loaded but no longer drawn. Buildings cast a short soft drop shadow
  (`_drawLongShadow`). New buildings pop in with an ease-out-back scale under a
  ground-coloured veil (`_drawSpawnAnimations`). Keep the road width and the car lane
  offset in step (`CarComponent._maxSafeLaneOffsetMagnitude` reads
  `GameConstants.roadWidth`).
- **Cars park instead of vanishing, and drive to the spot.** A house keeps two cars
  nose-in on a pavement apron in front of its block (`CarComponent.homeSpotFor`,
  slots assigned by `FlowGridGame._freeHomeSlot`; `GridRenderer._drawParkedCars`
  draws the glyph for every slot with no car out). A shop has three bays reached via
  the tongue and an in-lot corridor (`CarComponent.shopRoute` / `stallFor`, all
  measured from the anchor cell in `GameConstants.shop*`). `_rebuildSmoothPath`
  appends these spurs to the smooth path and scales the lane offset over them
  (`_laneFade`: 60% inside the lot so drones in and out pass on opposite sides, 0 over
  the last half tile). One drone moves inside a lot at a time (`_lotBusy`): entering
  drones hold on the driveway tile, leaving drones stay in their bay. Parked drones are
  skipped by the follow-the-leader scan. Never teleport a drone to a parking spot.
- Utility glyphs: roundabout = one-road-width ring on the
  `junctionRingRadius` pathing circle with a ground-colour island, signals = red/green lamps per
  approach, bridges = dark tick marks at each shore, tunnels = dashed edges and no
  portal, express lanes = tinned silver trace, one road wide, with a dashed centre line
  and a silver pad at each end. Its bow off the straight line is
  `GameConstants.expressLaneArc`, shared by the painter, the placement preview and
  `CarComponent`'s long-jump path -- change it in one place or drones leave the trace.
- **Never name other games in code, comments, docs, the store listing or commit
  messages.** See `changes_required.md` for why. Describe what the game does instead.
  Keep the look its own: no long single-light cast shadows, no ring timers, no map
  pins, no rounded-square blocks, no free-curving rounded-stroke roads. The circuit
  metaphor (traces, vias, chips, LEDs, drones) is the identity; drones stay colour-coded
  because that is how a player reads them.
- Houses spawn at most `GameConstants.homeParkingSlots` cars at a time
  (`FlowGridGame._carsOutFrom`); the timer holds at the threshold until one is home.

## Open work

`notes.txt` is the running backlog. Current items: Andes spawns one oversized mountain
instead of a range; car speed while waiting; traffic lights aren't meaningfully useful;
collision/overlap checks; game over should destroy the save (permadeath). Car jitter
was traced to the door node's non-null `side` triggering the smart-junction exit
bezier on the first path segment (`CarComponent._rebuildSmoothPath`), plus
nearest-neighbour sprite sampling; both are fixed.
Seen on 2026-09-03 and not yet fixed: `test/widget_test.dart` is empty, so
`flutter test` fails to compile; there is no in-game menu button, so switching maps
needs a game over (or a new browser tab); Andes mountains are small blobs rather than
ranges, so tunnels are rarely forced the way bridges now are on Nile.
Fixed the same day: bridges/tunnels. One token buys a corridor up to
`GameConstants.maxCorridorTiles`; a corridor can only start from a drivable tile (a
drag passing over a house used to anchor there and burn the token); a refused tile
never becomes the drag anchor; orphan cleanup refunds once per corridor; the
auto-extension that finishes a crossing rolls itself back if it never reaches land.
Nile rivers run edge to edge so there is no land gap to walk around.
