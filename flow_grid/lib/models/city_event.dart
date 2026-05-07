import 'package:flutter/material.dart';
import '../models/grid_cell.dart';

enum CityEventType {
  roadBlock,        // Random road tile becomes impassable for duration
  trafficSurge,     // A district's demand rate doubles temporarily
  bridgeMaintenance,// Bridge/tunnel speed reduced to 0.3x
  festival,         // Score bonus but +50% congestion in one district
}

class CityEvent {
  final CityEventType type;
  final String title;
  final String description;
  final GridPosition? affectedTile;   // null for district-wide events
  final int? affectedColor;           // null for infrastructure events
  final double duration;              // seconds
  double elapsed = 0;

  CityEvent({
    required this.type,
    required this.title,
    required this.description,
    this.affectedTile,
    this.affectedColor,
    required this.duration,
  });

  bool get isExpired => elapsed >= duration;

  IconData get icon {
    switch (type) {
      case CityEventType.roadBlock: return Icons.construction;
      case CityEventType.trafficSurge: return Icons.trending_up;
      case CityEventType.bridgeMaintenance: return Icons.build;
      case CityEventType.festival: return Icons.celebration;
    }
  }

  Color get color {
    switch (type) {
      case CityEventType.roadBlock: return Colors.orangeAccent;
      case CityEventType.trafficSurge: return Colors.redAccent;
      case CityEventType.bridgeMaintenance: return Colors.amber;
      case CityEventType.festival: return Colors.pinkAccent;
    }
  }
}
