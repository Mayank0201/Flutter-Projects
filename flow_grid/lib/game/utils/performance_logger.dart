import 'dart:developer';
import '../../models/game_constants.dart';

class PerformanceLogger {
  static const double frameThresholdMs = 16.67; // 60fps baseline
  
  final Map<String, List<double>> _metrics = {};
  final Map<String, DateTime> _starts = {};

  void start(String category) {
    _starts[category] = DateTime.now();
  }

  void stop(String category) {
    final start = _starts[category];
    if (start == null) return;
    
    final duration = DateTime.now().difference(start).inMicroseconds / 1000.0;
    _metrics.putIfAbsent(category, () => []).add(duration);
    
    if (GameConstants.debugInfrastructure && duration > frameThresholdMs) {
      log('⚠️ PERFORMANCE SPIKE [$category]: ${duration.toStringAsFixed(2)}ms');
    }
  }

  void report() {
    if (!GameConstants.debugInfrastructure) return;
    
    log('--- PERFORMANCE TELEMETRY ---');
    _metrics.forEach((category, values) {
      if (values.isEmpty) return;
      final avg = values.reduce((a, b) => a + b) / values.length;
      final maxVal = values.reduce((a, b) => a > b ? a : b);
      log('[$category] Avg: ${avg.toStringAsFixed(2)}ms | Max: ${maxVal.toStringAsFixed(2)}ms | Samples: ${values.length}');
    });
    _metrics.clear(); // Clear for next report interval
  }
}
