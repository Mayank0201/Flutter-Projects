import 'package:flutter/material.dart';

class GameConstants {
  static const double cellSize = 40.0;
  // Timing (Longer weeks, calmer demand — Mini Motorways pacing)
  static const double weekDuration = 85.0;
  static const double initialSpawnDelay = 15.0; // Ignored by new scheduler
  static const double minSpawnDelay = 8.0; // Ignored by new scheduler
  static const double carSpawnInterval = 12.0;
  static const double demandTickInterval = 13.0;
  static const int maxDemand = 6;
  static const double criticalDuration = 60.0;
  static const double overflowRecoveryDuration = 50.0;
  static const double overflowDeliveryRecovery = 0.06;

  // Maturity (Mini Motorways style evolution)
  static const int maturityThresholdWeeks = 4;
  static const int matureMaxDemand = 9;
  static const double matureRequestSpeedMultiplier = 1.15;
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
      0.95; // freshly placed: clearly visible parking apron around the building
  static const double lotMaxScale =
      1.05; // fully mature: 0.945*cellSize, safely inside the tile

  // Endless Scaling (Part 1 & 3)
  static const double highDemandHouseTriggerDuration = 22.0;
  static const double demandAgeScalingRate = 0.08;
  static const double minDemandInterval = 5.0;

  // Starting Inventories
  static const int startingRoadBudget = 25;
  static const int startingTunnels = 1; // was: startingBridges
  static const int startingBridges = 1;
  static const int startingTrafficLights = 0;
  static const int startingSmartJunctions = 0; // was: startingRoundabouts
  static const int startingExpressLanes = 0; // was 1 (removed for cleanup)

  static const int weeklyRoadBonus = 4;

  // Car
  static const double carSpeed = 130.0;

  // Presentation — Mini Motorways "calm" pass. Each of these switched a
  // decorative layer off; kept as flags so they can be brought back cheaply.
  static const bool ambientTimeOfDayTint = false; // warm/indigo week tint
  static const bool carTrails = false; // motion streak behind each car
  static const bool parkingHighlights = false; // yellow pulse under parked cars
  static const bool maturityAura = false; // white halo around mature shops

  // Building look (Mini Motorways): a shape is its flat colour plus the same
  // hue pushed ~30% toward the outline colour, offset downward, for a soft
  // "thickness" — no black drop shadows, no outlines on buildings.
  static const double buildingBevelMix = 0.30;
  // Destination lot card: a shade lighter than the road so the shop reads as
  // its own paved island, not more road.
  static const Color lotColor = roadColor; // lot cards are pavement

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

  // Colors - Soft Dark Mode
  static const Color backgroundColor = Color(0xFF2B303B);
  static const Color gridLineColor = Color(0xFF232830);
  // Mini Motorways dark mode: roads are a shade DARKER than the ground and
  // carry a thin light edge line; that edge is what makes them read.
  static const Color roadColor = Color(0xFF2C313B);
  static const Color roadFillColor = Color(0xFF2C313B);
  static const Color roadEdgeColor = Color(0xFF8C95A8);
  static const double roadWidth = 0.50; // fill, fraction of a tile
  static const double roadEdge = 0.045; // edge line, fraction of a tile
  // Long, soft, single-light-source shadow every building casts.
  static const Color buildingShadowColor = Color(0x38000000);
  static const double buildingShadowLength = 0.9; // in building sizes

  // Mountain colors (replaces water)
  static const Color mountainColor = Color(0xFF3A3D45); // Dark rocky gray
  static const Color mountainHighlightColor = Color(0xFF4A4E58); // Lighter peak
  static const Color mountainSnowColor = Color(0xFFD0D3DA); // Snow cap
  static const Color mountainEdgeColor = Color(0xFF2E3138); // Cliff edge

  // Tunnel & Express Lane
  static const Color tunnelColor = Color(0xFF8A7D6B);
  static const Color waterColor = Color(0xFF2C5E8A); // Deep River Blue
  static const Color bridgeColor = Color(0xFF7A8A99); // Slate Steel
  static const Color expressLaneColor = Color(0xFF9FE0B4); // Light Green
  static const Color expressLaneBorderColor = Color(0xFF6FB088);

  // Congestion — muted ochre/terracotta instead of flat-UI traffic-light
  // yellow/red, so it reads as calm information rather than an alarm.
  static const Color congestionLowColor = Color(0xFFC9A24B);
  static const Color congestionHighColor = Color(0xFFC17A5E);

  static const Color hudBackground = Color(0xFF22262E);
  static const Color hudText = Color(0xFFD8DCE2);

  static const Color carWindowColor = Color(0x80FFFFFF);

  // Muted, desaturated building colors
  // Mini Motorways identity set: clean, fairly saturated, one per district.
  static const List<Color> buildingColors = [
    Color(0xFFF04A5E), // 0: Red
    Color(0xFF3E86C6), // 1: Blue
    Color(0xFF5AC878), // 2: Green
    Color(0xFFF5A742), // 3: Orange
    Color(0xFFA65BA0), // 4: Purple
    Color(0xFFF2CF55), // 5: Yellow
  ];

  // Side/bevel shade of each colour (the "thickness" under the top face).
  static const List<Color> buildingDarkColors = [
    Color(0xFFB43847), // 0: Red
    Color(0xFF2E6494), // 1: Blue
    Color(0xFF43965A), // 2: Green
    Color(0xFFB87D31), // 3: Orange
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
