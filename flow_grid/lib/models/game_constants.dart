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
  static const Color backgroundColor = Color(0xFF161A22);
  static const Color gridLineColor = Color(0xFF232830);
  static const Color roadColor = Color(0xFF5F6572);
  static const Color roadFillColor = Color(0xFF6C7280);

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

  // Congestion
  static const Color congestionLowColor = Color(0xFFE6B800); // Yellow
  static const Color congestionHighColor = Color(0xFFE74C3C); // Red

  static const Color hudBackground = Color(0xFF22262E);
  static const Color hudText = Color(0xFFD8DCE2);

  static const Color carWindowColor = Color(0x80FFFFFF);

  // Muted, desaturated building colors
  static const List<Color> buildingColors = [
    Color(0xFFE05A5A), // 0: Muted Red
    Color(0xFF5AC0D0), // 1: Muted Cyan (was Blue)
    Color(0xFF5AC47A), // 2: Muted Green
    Color(0xFFD98A4A), // 3: Muted Orange (was Yellow)
    Color(0xFF9B7DBF), // 4: Muted Purple
    Color(0xFFE6C15A), // 5: Muted Yellow (was Orange)
  ];

  static const List<Color> buildingDarkColors = [
    Color(0xFFB84848), // 0: Dark Red
    Color(0xFF388EA0), // 1: Dark Cyan (was Blue)
    Color(0xFF489E60), // 2: Dark Green
    Color(0xFFB06E38), // 3: Dark Orange (was Yellow)
    Color(0xFF7E5FA0), // 4: Dark Purple
    Color(0xFFC0A048), // 5: Dark Yellow (was Orange)
  ];

  static Color getBuildingColor(int index) =>
      buildingColors[index % buildingColors.length];

  static Color getBuildingDarkColor(int index) =>
      buildingDarkColors[index % buildingDarkColors.length];

  // --- Performance & Stabilization (Task 7 & 13) ---
  static const bool debugInfrastructure = false;
  static const bool showPerformanceOverlay = true;
  
  // Tick Rates (Hz) - Task 5
  static const double logicTickRate = 15.0;     // Traffic, logic updates
  static const double congestionTickRate = 5.0; // Congestion analytics
  static const double satisfactionTickRate = 2.0; // Global metrics
  static const double spawnCheckTickRate = 1.0;   // District expansion
  
  // Render Chunks - Task 1
  static const int chunkSize = 16; // tiles per chunk
}
