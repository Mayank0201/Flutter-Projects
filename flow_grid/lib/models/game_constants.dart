import 'package:flutter/material.dart';

class GameConstants {
  // Timing (Longer weeks, calmer demand — Mini Motorways pacing)
  static const double weekDuration = 75.0; // Faster week (was 90s)
  static const double initialSpawnDelay = 15.0; // Ignored by new scheduler
  static const double minSpawnDelay = 8.0; // Ignored by new scheduler
  static const double carSpawnInterval = 12.0; // Rebalanced (was 8s)
  static const double demandTickInterval = 14.0; 
  static const int maxDemand = 6;
  static const double criticalDuration = 45.0; // Slightly longer for gradual system
  static const double overflowRecoveryDuration = 120.0; // Slow natural decay
  static const double overflowDeliveryRecovery = 0.125; // 8 deliveries to clear 100%

  // Maturity (Mini Motorways style evolution)
  static const int maturityThresholdWeeks = 3;
  static const int matureMaxDemand = 10;
  static const double matureRequestSpeedMultiplier = 1.35;
  static const double matureOverflowBuildupMultiplier = 1.25;

  // Endless Scaling (Part 1 & 3)
  static const double highDemandHouseTriggerDuration = 25.0; // Seconds at 6+ dots
  static const double demandAgeScalingRate = 0.15; // +15% demand speed per week after maturity
  static const double minDemandInterval = 3.5; // Clamp for late game dots

  // Starting Inventories
  static const int startingRoadBudget = 20;
  static const int startingTunnels = 1; // was: startingBridges
  static const int startingTrafficLights = 0;
  static const int startingSmartJunctions = 0; // was: startingRoundabouts
  static const int startingExpressLanes = 0; // was 1 (removed for cleanup)

  static const int weeklyRoadBonus = 5;

  // Car
  static const double carSpeed = 135.0;

  // Terrain & Capacity
  static const double mountainTerrainPenalty =
      0.6; // speed multiplier near mountains
  static const double tunnelSpeedBonus = 1.0; // tunnels remove penalty
  static const double expressLaneSpeed = 1.25; // 0.8 path weight
  static const int roadCapacityDefault = 5;
  static const double roadCapacityCongestedThreshold = 0.8;

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
  static const Color backgroundColor = Color(0xFF1C1F26);
  static const Color gridLineColor = Color(0xFF2A2F3A);
  static const Color roadColor = Color(0xFF5F6572);
  static const Color roadFillColor = Color(0xFF6C7280);

  // Mountain colors (replaces water)
  static const Color mountainColor = Color(0xFF3A3D45); // Dark rocky gray
  static const Color mountainHighlightColor = Color(0xFF4A4E58); // Lighter peak
  static const Color mountainSnowColor = Color(0xFFD0D3DA); // Snow cap
  static const Color mountainEdgeColor = Color(0xFF2E3138); // Cliff edge

  // Tunnel & Express Lane
  static const Color tunnelColor = Color(0xFF8A7D6B);
  static const Color expressLaneColor = Color(0xFF4A9062); // Subtle Green
  static const Color expressLaneBorderColor = Color(0xFF346344);

  // Congestion
  static const Color congestionLowColor = Color(0xFFE6B800); // Yellow
  static const Color congestionHighColor = Color(0xFFE74C3C); // Red

  static const Color hudBackground = Color(0xFF22262E);
  static const Color hudText = Color(0xFFD8DCE2);

  static const Color carWindowColor = Color(0x80FFFFFF);

  // Muted, desaturated building colors
  static const List<Color> buildingColors = [
    Color(0xFFE05A5A), // Muted Red
    Color(0xFF5A8DEE), // Muted Blue
    Color(0xFF5AC47A), // Muted Green
    Color(0xFFE6C15A), // Muted Yellow
    Color(0xFF9B7DBF), // Muted Purple
    Color(0xFFD98A4A), // Muted Orange
  ];

  static const List<Color> buildingDarkColors = [
    Color(0xFFB84848), // Dark Red
    Color(0xFF4870C0), // Dark Blue
    Color(0xFF489E60), // Dark Green
    Color(0xFFC0A048), // Dark Yellow
    Color(0xFF7E5FA0), // Dark Purple
    Color(0xFFB06E38), // Dark Orange
  ];

  static Color getBuildingColor(int index) =>
      buildingColors[index % buildingColors.length];

  static Color getBuildingDarkColor(int index) =>
      buildingDarkColors[index % buildingDarkColors.length];
}
