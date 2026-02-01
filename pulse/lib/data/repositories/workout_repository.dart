import '../local/hive_boxes.dart';
import '../models/workout.dart';
import 'package:hive/hive.dart';

class WorkoutRepository {
  Box<Workout>? _workoutBox;

  // Ensure the box is open before performing any operations
  Future<Box<Workout>> _getWorkoutBox() async {
    if (_workoutBox == null || !_workoutBox!.isOpen) {
      try {
        _workoutBox = await Hive.openBox<Workout>(HiveKeys.workoutsBox);
      } catch (e) {
        print('Error opening workouts box: $e');
        rethrow; // Rethrow the error if necessary
      }
    }
    return _workoutBox!;
  }

  Future<void> addWorkout(Workout workout) async {
    try {
      final box = await _getWorkoutBox();
      await box.put(workout.id, workout);
    } catch (e) {
      print('Error adding workout: $e');
    }
  }

  Future<Workout?> getWorkout(String id) async {
    try {
      final box = await _getWorkoutBox();
      return box.get(id);
    } catch (e) {
      print('Error getting workout: $e');
      return null;
    }
  }

  Future<void> updateWorkout(Workout workout) async {
    try {
      final box = await _getWorkoutBox();
      await box.put(workout.id, workout);
    } catch (e) {
      print('Error updating workout: $e');
    }
  }

  Future<void> deleteWorkout(String id) async {
    try {
      final box = await _getWorkoutBox();
      await box.delete(id);
    } catch (e) {
      print('Error deleting workout: $e');
    }
  }

  Future<List<Workout>> getAllWorkouts() async {
    try {
      final box = await _getWorkoutBox();
      return box.values.toList();
    } catch (e) {
      print('Error getting all workouts: $e');
      return [];
    }
  }
}
