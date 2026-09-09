import 'package:flutter/material.dart';

class GameConstants {
  static const double cellSize = 40.0;
  // Timing (longer weeks, calmer demand)
  static const double weekDuration = 85.0;
  static const double initialSpawnDelay = 15.0; // Ignored by new scheduler
  static const double minSpawnDelay = 8.0; // Ignored by new scheduler
  static const double carSpawnInterval = 12.0;
  static const double demandTickInterval = 13.0;
  static const int maxDemand = 6;
  static const double criticalDuration = 60.0;
  static const double overflowRecoveryDuration = 50.0;
  static const double overflowDeliveryRecovery = 0.06;

  // Maturity (shops grow with age). The age counter starts at 0 on the week a
  // shop is placed, so a threshold of 3 means a shop that appeared in week 1
  // matures as week 4 begins -- which is when a player expects "four weeks
  // old" to mean something.
  static const int maturityThresholdWeeks = 3;
  static const int matureMaxDemand = 9;
  static const double matureRequestSpeedMultiplier = 1.25;
  static const double matureOverflowBuildupMultiplier = 1.10;

  // Maturity — parking lot growth (visual only, driven by the same
  // age/maturityThresholdWeeks signal as matureMaxDemand above; see
  // GridRenderer._drawDestination). Scales are relative to the destination's
  // rendered building "size" (cellSize * BuildingProfile.commercial.renderScale
  // == 0.90 * cellSize, see below), not the raw cellSize, so the lot always
  // stays safely inside its own tile even at lotMaxScale.
  //
  // [FIX] Was 0.78 / 1.15. When the destination-vs-house size fix enlarged
  // the building body factor (_drawDestination's bSize, now 0.78 of `size`
  // -- see that method), the OLD lotMinScale (0.78) put the freshly-placed
  // lot at almost exactly the building's own width, and briefly (before
  // that follow-up fix) even smaller than it -- the building visibly
  // overflowed its own parking lot. Raised to 0.85/1.08 so the lot was
  // always at least somewhat bigger than the building, but live feedback
  // ("right and left and top of destination houses [need to be] bigger...
  // house takes all the area, I want it to have like a parking lot") found
  // that margin still read as too thin to register as a visible lot.
  // Raised further -- margin per side goes from ~8%/12% of cellSize
  // (min/max maturity) to ~15%/20%, a clearly visible parking apron on
  // every side, while lotMaxScale*renderScale (1.05*0.90=0.945*cellSize)
  // stays safely under 1.0*cellSize.
  static const double lotMinScale =
      1.02; // lot card ~1.8 tiles: room for three bays plus the corridor
  static const double lotMaxScale =
      1.20; // fully mature: visibly larger pad, and the chip grows with it

  // Endless Scaling (Part 1 & 3)
  static const double highDemandHouseTriggerDuration = 22.0;
  // How much faster a shop asks for a delivery per week of age. The demand
  // interval is demandTickInterval / (1 + age * demandAgeScalingRate), then
  // multiplied by matureRequestSpeedMultiplier once the shop is mature, and
  // floored at minDemandInterval.
  //
  // [FIX] Was 0.08 with matureRequestSpeedMultiplier 1.15 and a 5.0 floor.
  // That gave 13.0s at age 0, 11.2s at age 2, 8.6s at age 4, 7.6s at 6 and
  // 6.9s at 8 -- steps of well under a second per week early on, so a player
  // watching a shop turn four saw no change in cadence. Worse, the maturity
  // beat *relaxed* the shop: the ceiling jumps maxDemand 6 -> matureMaxDemand
  // 9 at the same moment, so three extra LEDs of headroom arrived while the
  // tick only sped up by 15%. Retuned so age reads on screen: 13.0s at age 0
  // (a new shop is still comfortable), 10.0s at 2, 6.5s at 4 -- a visible
  // step at the maturity beat that pairs with the pad growth and the amber
  // LED -- 5.5s at 6, 4.7s at 8, hitting the floor around age 11.
  static const double demandAgeScalingRate = 0.15;
  // Fastest a shop can ever ask, however old it gets. Lowered 5.0 -> 4.0 so
  // ages 6..11 still separate instead of all clamping to the same value.
  static const double minDemandInterval = 4.0;

  // Starting Inventories
  static const int startingRoadBudget = 25;
  static const int startingTunnels = 1; // was: startingBridges
  static const int startingBridges = 1;
  // Longest tunnel or bridge one token buys, in tiles. Rivers are up to
  // five tiles wide, so a single token always spans one.
  static const int maxCorridorTiles = 8;
  static const int startingTrafficLights = 0;
  static const int startingSmartJunctions = 0; // was: startingRoundabouts
  static const int startingExpressLanes = 0; // was 1 (removed for cleanup)

  static const int weeklyRoadBonus = 4;

  // Car
  static const double carSpeed = 130.0;

  // Presentation — calm-look pass. Each of these switched a
  // decorative layer off; kept as flags so they can be brought back cheaply.
  static const bool ambientTimeOfDayTint = false; // warm/indigo week tint
  static const bool carTrails = false; // motion streak behind each car
  static const bool parkingHighlights = false; // yellow pulse under parked cars
  static const bool maturityAura = false; // white halo around mature shops

  // Building look: a shape is its flat colour plus the same
  // hue pushed ~30% toward the outline colour, offset downward, for a soft
  // "thickness" — no black drop shadows, no outlines on buildings.
  static const double buildingBevelMix = 0.30;
  // Destination lot card: a shade lighter than the road so the shop reads as
  // its own paved island, not more road.
  // Shop lot pad: a dark socket a shade lighter than the board, with a
  // copper outline; copper fill is reserved for traces and via pads.
  static const Color lotColor = Color(0xFF223A3E); // lot cards are pavement

  // Destinations occupy a 2x2 footprint: the anchor cell (the one that owns
  // demand/age/driveway state) plus three `partOf` cells. See
  // GridManager.destinationFootprint for how the footprint hangs off the
  // entry side.
  static const int destinationFootprintSize = 2;

  // Terrain & Capacity
  static const double mountainTerrainPenalty =
      0.6; // speed multiplier near mountains
  static const double tunnelSpeedBonus = 1.0; // tunnels remove penalty
  static const double expressLaneSpeed =
      1.4; // 0.7 path weight (increased from 1.25)
  static const int roadCapacityDefault = 5;
  static const int avenueCapacity = 15;
  static const int highwayCapacity = 45;
  static const int metroCapacity = 120;
  static const int elevatedRailCapacity = 180;

  static const double metroSpeedMultiplier = 2.2;
  static const double elevatedRailSpeedMultiplier = 2.8;
  static const double highwaySpeedMultiplier = 1.8;

  static const double roadCapacityCongestedThreshold = 0.8;

  // Satisfaction System (Part 4)
  static const double satisfactionDecayRate = 0.005; // per car delivery delay
  static const double satisfactionRecoveryRate = 0.02; // per on-time delivery
  static const double criticalSatisfactionThreshold = 0.35;

  // Regional Expansion (Part 3)
  static const int sectorUnlockBaseCost = 1500;
  static const int sectorUnlockScoreThreshold = 500;

  // Traffic Signals
  static const double trafficSignalInterval = 3.0; // seconds per phase

  // Delivery Efficiency
  static const int deliveryTimeBonus = 50;
  static const int deliveryTimePenalty = -25;
  static const double deliveryTimeThreshold = 30.0; // seconds for "on time"

  // Vehicle Type Speed Multipliers
  static const double truckSpeedMultiplier = 0.6;
  static const double serviceVanSpeedMultiplier = 1.3;

  // Colors - circuit board. Deep board-ink ground, copper traces for
  // roads, chips for buildings, glowing dots for cars.
  static const Color backgroundColor = Color(0xFF14262A);
  static const Color gridLineColor = Color(0xFF1A2F33);
  // Roads are copper traces: a muted copper fill with a lighter copper
  // edge, straight runs, 45-degree chamfered corners, via pads at ends and
  // junctions (GridRenderer paints the pads).
  static const Color roadColor = Color(0xFF7E5F36);
  static const Color roadFillColor = Color(0xFF7E5F36);
  static const Color roadEdgeColor = Color(0xFFBF945C);
  static const double roadWidth = 0.60; // fill, fraction of a tile
  static const double roadEdge = 0.045; // edge line, fraction of a tile
  // Smart-junction ring centreline radius, fraction of a tile. Cars drive
  // this circle and the renderer paints one road-width around it, so 0.5
  // keeps the roundabout inside its own tile.
  static const double junctionRingRadius = 0.5;
  // Short, soft drop shadow under every building (lit from above).
  static const Color buildingShadowColor = Color(0x46000000);
  static const double buildingShadowLength = 0.16; // in building sizes

  // Parking. A house keeps two cars nose-in on a small pavement apron in
  // front of its block; a shop has two painted stalls. Cars drive a short
  // spur on and off the spot (no teleport), fade their lane offset to zero
  // over that spur so they land exactly on it, and pivot in place when
  // they set off again.
  static const int homeParkingSlots = 2;
  static const double houseBlockBackShift = 0.12; // tiles, away from the road
  static const double houseBlockScale = 0.85; // of the residential renderScale
  static const double homeParkingAlong = 0.30; // tiles from the house centre
  static const double homeParkingLateral = 0.10; // tiles off the driveway axis
  static const double parkingLaneFadeTiles = 0.5;
  // Inside a shop lot the lane offset is kept at this fraction so drones
  // going in and coming out pass on opposite sides of the corridor.
  static const double lotLaneScale = 0.6;

  // Ambient signal towers on empty tiles (the board's "trees"): a thin
  // mast on a small base with two crossbars and a warm beacon on top.
  static const Color towerMastColor = Color(0xFF6E8087);
  static const Color towerBaseColor = Color(0xFF2E3F44);
  static const Color towerBeaconColor = Color(0xFFE0736A);
  static const double parkingCornerRadius = 0.20; // tiles, in-lot corners
  // Shop lot, measured from the anchor cell centre in tiles: positive
  // "along" is toward the road (the tongue mouth is at +0.5), "strip" runs
  // along the lot face the driveway meets. Cars come in through the tongue,
  // drive the corridor, and turn into a bay nose toward the block.
  static const int shopBays = 3;
  static const double shopCorridorAlong = 0.16;
  static const double shopBayAlong = -0.22;
  static const double shopBayFirst = 0.36; // strip offset of bay 0
  static const double shopBayPitch = 0.36; // each further bay is one pitch on
  static const double carPivotRate = 20.0; // rad/s, max heading change
  // Drone disc radius as a fraction of the vehicle size (0.34 tile), so a
  // drone is about 0.4 tile across: clearly readable at phone zoom.
  static const double droneRadius = 0.44;

  // Mountain colors (replaces water)
  static const Color mountainColor = Color(0xFF2A4147); // Dark teal rock
  static const Color mountainHighlightColor = Color(0xFF37545B); // Lighter crown
  static const Color mountainSnowColor = Color(0xFFD0D3DA); // (unused now)
  static const Color mountainEdgeColor = Color(0xFF1F3239); // Cliff edge

  // Tunnel & Express Lane
  static const Color tunnelColor = Color(0xFF8A7D6B);
  static const Color waterColor = Color(0xFF1F4B57); // deep teal pool
  static const Color waterEdgeColor = Color(0xFF6FB3BE);
  static const Color bridgeColor = roadColor; // the road just continues over water
  // How far an express trace bows off the straight line between its two
  // ends, as a fraction of its length. CarComponent's long-jump branch uses
  // the same number, or drones would fly off the painted trace.
  static const double expressLaneArc = 0.06;
  static const Color expressLaneColor = Color(0xFFB9C4CC); // tinned (silver) trace
  static const Color expressLaneBorderColor = Color(0xFF6E7B84);

  // Congestion — muted ochre/terracotta instead of flat-UI traffic-light
  // yellow/red, so it reads as calm information rather than an alarm.
  static const Color congestionLowColor = Color(0xFFC9A24B);
  static const Color congestionHighColor = Color(0xFFC17A5E);

  static const Color hudBackground = Color(0xFF10191C);
  static const Color hudText = Color(0xFFD8DCE2);

  static const Color carWindowColor = Color(0x80FFFFFF);

  // Muted, desaturated building colors
  // Identity set: clean, fairly saturated, one per district.
  static const List<Color> buildingColors = [
    Color(0xFFF04A5E), // 0: Red
    Color(0xFF3E86C6), // 1: Blue
    Color(0xFF5AC878), // 2: Green
    Color(0xFFE8853C), // 3: Orange
    Color(0xFFA65BA0), // 4: Purple
    Color(0xFFF2CF55), // 5: Yellow
  ];

  // Side/bevel shade of each colour (the "thickness" under the top face).
  static const List<Color> buildingDarkColors = [
    Color(0xFFB43847), // 0: Red
    Color(0xFF2E6494), // 1: Blue
    Color(0xFF43965A), // 2: Green
    Color(0xFFA85E26), // 3: Orange
    Color(0xFF7C4478), // 4: Purple
    Color(0xFFB59B40), // 5: Yellow
  ];

  static Color getBuildingColor(int index) =>
      buildingColors[index % buildingColors.length];

  static Color getBuildingDarkColor(int index) =>
      buildingDarkColors[index % buildingDarkColors.length];

  // --- Performance & Stabilization (Task 7 & 13) ---
  static const bool debugInfrastructure = false;
  static const bool showPerformanceOverlay = true;

  // Tick Rates (Hz) - Task 5
  static const double logicTickRate = 15.0; // Traffic, logic updates
  static const double congestionTickRate = 5.0; // Congestion analytics
  static const double satisfactionTickRate = 2.0; // Global metrics
  static const double spawnCheckTickRate = 1.0; // District expansion

  // Render Chunks - Task 1
  static const int chunkSize = 16; // tiles per chunk
}
