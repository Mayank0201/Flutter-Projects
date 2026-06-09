import 'package:flutter/material.dart';
import 'grid_cell.dart';

/// District types that define the personality of each neighborhood.
/// Each type affects demand patterns, vehicle mix, scoring, and visuals.
enum DistrictType { residential, industrial, commercial, tech }

/// Immutable profile defining the gameplay behavior of a district type.
class DistrictProfile {
  final DistrictType type;
  final String label;
  final double demandMultiplier;       // Scales demand tick speed
  final double scoreMultiplier;        // Scales delivery score
  final Map<VehicleType, double> vehicleWeights; // Spawn probability weights
  final double congestionFactor;       // Traffic buildup multiplier
  final Color accentColor;             // Visual tint for buildings
  final IconData icon;                 // HUD/UI icon

  const DistrictProfile({
    required this.type,
    required this.label,
    required this.demandMultiplier,
    required this.scoreMultiplier,
    required this.vehicleWeights,
    required this.congestionFactor,
    required this.accentColor,
    required this.icon,
  });

  /// Balanced traffic, moderate growth. The default baseline.
  static const residential = DistrictProfile(
    type: DistrictType.residential,
    label: 'Residential',
    demandMultiplier: 1.0,
    scoreMultiplier: 1.0,
    vehicleWeights: {VehicleType.car: 0.8, VehicleType.serviceVan: 0.2},
    congestionFactor: 1.0,
    accentColor: Color(0xFF8899AA),  // Neutral slate
    icon: Icons.home_rounded,
  );

  /// Slower heavy vehicles, higher congestion, larger traffic bursts.
  static const industrial = DistrictProfile(
    type: DistrictType.industrial,
    label: 'Industrial',
    demandMultiplier: 0.7,           // Slower demand generation...
    scoreMultiplier: 1.5,            // ...but higher value per delivery
    vehicleWeights: {VehicleType.truck: 0.6, VehicleType.car: 0.3, VehicleType.serviceVan: 0.1},
    congestionFactor: 1.4,           // Heavy trucks = more road congestion
    accentColor: Color(0xFF9A8A6A),  // Warm industrial amber
    icon: Icons.factory_rounded,
  );

  /// Frequent small deliveries, dense intersections.
  static const commercial = DistrictProfile(
    type: DistrictType.commercial,
    label: 'Commercial',
    demandMultiplier: 1.4,           // Rapid small orders
    scoreMultiplier: 0.8,            // Lower per-delivery value
    vehicleWeights: {VehicleType.serviceVan: 0.5, VehicleType.car: 0.5},
    congestionFactor: 1.2,
    accentColor: Color(0xFF7AA89E),  // Teal commerce
    icon: Icons.storefront_rounded,
  );

  /// Extremely fast requests, low vehicle count, high efficiency scoring.
  static const tech = DistrictProfile(
    type: DistrictType.tech,
    label: 'Tech',
    demandMultiplier: 1.8,           // Very fast requests
    scoreMultiplier: 2.0,            // High-value deliveries
    vehicleWeights: {VehicleType.car: 0.9, VehicleType.serviceVan: 0.1},
    congestionFactor: 0.7,           // Efficient, low-congestion traffic
    accentColor: Color(0xFF7A8EC8),  // Cool tech blue
    icon: Icons.memory_rounded,
  );

  /// Look up profile by type.
  static DistrictProfile fromType(DistrictType type) {
    switch (type) {
      case DistrictType.residential: return residential;
      case DistrictType.industrial: return industrial;
      case DistrictType.commercial: return commercial;
      case DistrictType.tech: return tech;
    }
  }

  /// All available profiles.
  static const List<DistrictProfile> all = [residential, industrial, commercial, tech];

  /// Pick a weighted-random vehicle type from this profile's weights.
  VehicleType pickVehicleType(double randomValue) {
    double cumulative = 0;
    for (final entry in vehicleWeights.entries) {
      cumulative += entry.value;
      if (randomValue <= cumulative) return entry.key;
    }
    return VehicleType.car; // fallback
  }
}
