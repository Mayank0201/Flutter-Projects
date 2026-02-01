import '../local/hive_boxes.dart';
import '../models/exercise.dart';
import 'package:hive/hive.dart';

class ExerciseRepository {
  Box<Exercise>? _exerciseBox;

  // Ensure the box is open before performing any operations
  Future<Box<Exercise>> _getExerciseBox() async {
    if (_exerciseBox == null || !_exerciseBox!.isOpen) {
      try {
        _exerciseBox = await Hive.openBox<Exercise>(HiveKeys.exercisesBox);
      } catch (e) {
        print('Error opening exercises box: $e');
        rethrow; // Rethrow the error if necessary
      }
    }
    return _exerciseBox!;
  }

  Future<void> addExercise(Exercise exercise) async {
    try {
      final box = await _getExerciseBox();
      await box.put(exercise.id, exercise);
    } catch (e) {
      print('Error adding exercise: $e');
    }
  }

  Future<Exercise?> getExercise(String id) async {
    try {
      final box = await _getExerciseBox();
      return box.get(id);
    } catch (e) {
      print('Error getting exercise: $e');
      return null;
    }
  }

  Future<void> updateExercise(Exercise exercise) async {
    try {
      final box = await _getExerciseBox();
      await box.put(exercise.id, exercise);
    } catch (e) {
      print('Error updating exercise: $e');
    }
  }

  Future<void> deleteExercise(String id) async {
    try {
      final box = await _getExerciseBox();
      await box.delete(id);
    } catch (e) {
      print('Error deleting exercise: $e');
    }
  }

  Future<List<Exercise>> getAllExercises() async {
    try {
      final box = await _getExerciseBox();
      return box.values.toList();
    } catch (e) {
      print('Error getting all exercises: $e');
      return [];
    }
  }
}
