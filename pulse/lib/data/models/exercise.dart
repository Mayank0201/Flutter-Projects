import 'package:hive/hive.dart';
import 'workout_set.dart';
part 'exercise.g.dart';

@HiveType(typeId: 0)
class Exercise extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String muscleGroup;

  @HiveField(3)
  final int orderIndex; //position of the exercise in the workout

  @HiveField(4)
  final List<WorkoutSet> sets;

  Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.orderIndex,
    required this.sets,
  });
}
