import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/workout_set.dart';

class HiveInitializer {
  static Future<void> initializeHive() async {
    await Hive.initFlutter();

    // Register adapters
    try {
      Hive.registerAdapter(ExerciseAdapter());
      Hive.registerAdapter(WorkoutAdapter());
      Hive.registerAdapter(WorkoutSetAdapter());
      Hive.registerAdapter(WorkoutStatusAdapter());
    } catch (e) {
      print('Adapter registration error: $e');
    }
  }

  static Future<void> openBoxes() async {
    try {
      await Hive.openBox<Exercise>('exercises');
      await Hive.openBox<Workout>('workouts');
      await Hive.openBox<WorkoutSet>('workout_sets');
    } catch (e) {
      print('Error opening Hive boxes: $e');
    }
  }
}
