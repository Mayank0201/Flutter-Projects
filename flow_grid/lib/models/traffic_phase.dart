import 'dart:ui';

enum TrafficPhase { morningRush, midday, eveningRush, calm }

class TrafficPhaseModifiers {
  final double residentialSpawnWeight; // Multiplier for residential dispatch urgency
  final double destinationSpawnWeight; // Multiplier for destination urgency
  final double demandRateMultiplier;   // Overall demand generation speed modifier
  final double congestionMultiplier;   // Modifier for road capacity load
  
  const TrafficPhaseModifiers({
    required this.residentialSpawnWeight,
    required this.destinationSpawnWeight,
    required this.demandRateMultiplier,
    required this.congestionMultiplier,
  });

  /// Interpolates between two modifiers
  static TrafficPhaseModifiers lerp(TrafficPhaseModifiers a, TrafficPhaseModifiers b, double t) {
    return TrafficPhaseModifiers(
      residentialSpawnWeight: lerpDouble(a.residentialSpawnWeight, b.residentialSpawnWeight, t) ?? a.residentialSpawnWeight,
      destinationSpawnWeight: lerpDouble(a.destinationSpawnWeight, b.destinationSpawnWeight, t) ?? a.destinationSpawnWeight,
      demandRateMultiplier: lerpDouble(a.demandRateMultiplier, b.demandRateMultiplier, t) ?? a.demandRateMultiplier,
      congestionMultiplier: lerpDouble(a.congestionMultiplier, b.congestionMultiplier, t) ?? a.congestionMultiplier,
    );
  }
}

class TrafficClock {
  TrafficPhase currentPhase = TrafficPhase.calm;
  double phaseProgress = 0.0;
  double blendFactor = 0.0; // 0.0 = pure current phase, 1.0 = next phase

  // Phase configurations
  static const Map<TrafficPhase, TrafficPhaseModifiers> phaseConfigs = {
    TrafficPhase.morningRush: TrafficPhaseModifiers(
      residentialSpawnWeight: 1.4,
      destinationSpawnWeight: 0.7,
      demandRateMultiplier: 1.2,
      congestionMultiplier: 1.3,
    ),
    TrafficPhase.midday: TrafficPhaseModifiers(
      residentialSpawnWeight: 1.0,
      destinationSpawnWeight: 1.0,
      demandRateMultiplier: 1.0,
      congestionMultiplier: 1.0,
    ),
    TrafficPhase.eveningRush: TrafficPhaseModifiers(
      residentialSpawnWeight: 0.7,
      destinationSpawnWeight: 1.4,
      demandRateMultiplier: 1.2,
      congestionMultiplier: 1.3,
    ),
    TrafficPhase.calm: TrafficPhaseModifiers(
      residentialSpawnWeight: 0.8,
      destinationSpawnWeight: 0.8,
      demandRateMultiplier: 0.7,
      congestionMultiplier: 0.8,
    ),
  };

  void update(double weekProgress) {
    // Week progresses 0.0 to 1.0
    // Define phase thresholds
    // Morning Rush: 0.0 - 0.2
    // Midday: 0.2 - 0.5
    // Evening Rush: 0.5 - 0.7
    // Calm: 0.7 - 1.0

    double phaseStart = 0.0;
    double phaseEnd = 0.2;
    TrafficPhase nextPhase = TrafficPhase.midday;

    if (weekProgress < 0.2) {
      currentPhase = TrafficPhase.morningRush;
      nextPhase = TrafficPhase.midday;
      phaseStart = 0.0;
      phaseEnd = 0.2;
    } else if (weekProgress < 0.5) {
      currentPhase = TrafficPhase.midday;
      nextPhase = TrafficPhase.eveningRush;
      phaseStart = 0.2;
      phaseEnd = 0.5;
    } else if (weekProgress < 0.7) {
      currentPhase = TrafficPhase.eveningRush;
      nextPhase = TrafficPhase.calm;
      phaseStart = 0.5;
      phaseEnd = 0.7;
    } else {
      currentPhase = TrafficPhase.calm;
      nextPhase = TrafficPhase.morningRush;
      phaseStart = 0.7;
      phaseEnd = 1.0;
    }

    final phaseDuration = phaseEnd - phaseStart;
    phaseProgress = (weekProgress - phaseStart) / phaseDuration;

    // Blend during the last 20% of the phase
    if (phaseProgress > 0.8) {
      blendFactor = (phaseProgress - 0.8) / 0.2;
    } else {
      blendFactor = 0.0;
    }

    _modifiers = TrafficPhaseModifiers.lerp(
      phaseConfigs[currentPhase]!,
      phaseConfigs[nextPhase]!,
      blendFactor,
    );
  }

  TrafficPhaseModifiers _modifiers = phaseConfigs[TrafficPhase.calm]!;
  TrafficPhaseModifiers get modifiers => _modifiers;
}
