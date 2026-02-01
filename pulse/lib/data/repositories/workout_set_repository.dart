import '../local/hive_boxes.dart';
import '../models/workout_set.dart';
import 'package:hive/hive.dart';

class WorkoutSetRepository {
  Box<WorkoutSet>? _workoutSetBox;

  // Ensure the box is open before performing any operations
  Future<Box<WorkoutSet>> _getWorkoutSetBox() async {
    if (_workoutSetBox == null || !_workoutSetBox!.isOpen) {
      try {
        _workoutSetBox = await Hive.openBox<WorkoutSet>(
          HiveKeys.workoutSetsBox,
        );
      } catch (e) {
        print('Error opening workout sets box: $e');
        rethrow; // Rethrow the error if necessary
      }
    }
    return _workoutSetBox!;
  }

  Future<void> addWorkoutSet(WorkoutSet workoutSet) async {
    try {
      final box = await _getWorkoutSetBox();
      await box.put(workoutSet.id, workoutSet);
    } catch (e) {
      print('Error adding workout set: $e');
    }
  }

  Future<WorkoutSet?> getWorkoutSet(String id) async {
    try {
      final box = await _getWorkoutSetBox();
      return box.get(id);
    } catch (e) {
      print('Error getting workout set: $e');
      return null;
    }
  }

  Future<void> updateWorkoutSet(WorkoutSet workoutSet) async {
    try {
      final box = await _getWorkoutSetBox();
      await box.put(workoutSet.id, workoutSet);
    } catch (e) {
      print('Error updating workout set: $e');
    }
  }

  Future<void> deleteWorkoutSet(String id) async {
    try {
      final box = await _getWorkoutSetBox();
      await box.delete(id);
    } catch (e) {
      print('Error deleting workout set: $e');
    }
  }

  Future<List<WorkoutSet>> getAllWorkoutSets() async {
    try {
      final box = await _getWorkoutSetBox();
      return box.values.toList();
    } catch (e) {
      print('Error getting all workout sets: $e');
      return [];
    }
  }
}
