import 'package:hive/hive.dart';
part 'workout_set.g.dart';

@HiveType(typeId: 2)
class WorkoutSet extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int reps; //repetitions

  @HiveField(2)
  final double weight;

  @HiveField(3)
  final DateTime performedAt;

  @HiveField(4)
  final bool isCompleted;

  WorkoutSet({
    required this.id,
    required this.reps,
    required this.weight,
    required this.performedAt,
    required this.isCompleted,
  });
}
