import 'package:hive/hive.dart';
import 'exercise.dart';
part 'workout.g.dart';

@HiveType(typeId: 3)
enum WorkoutStatus {
  @HiveField(0)
  notStarted,
  @HiveField(1)
  inProgress,
  @HiveField(2)
  completed,
  @HiveField(3)
  paused,
}

@HiveType(typeId: 1)
class Workout extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime startedAt;

  @HiveField(2)
  final DateTime? endedAt;

  @HiveField(3)
  final WorkoutStatus status;

  @HiveField(4)
  final String? notes;

  @HiveField(5)
  final List<Exercise> exercises;

  Workout({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.status,
    this.notes,
    required this.exercises,
  });
}
