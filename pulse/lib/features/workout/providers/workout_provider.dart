import 'package:flutter/material.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../../data/models/workout.dart';

class WorkoutProvider extends ChangeNotifier {
  final WorkoutRepository _workoutRepository = WorkoutRepository();
  List<Workout> _workouts = [];

  bool isLoading = false;

  bool get loading => isLoading;

  List<Workout> get workouts => _workouts;

  Future<void> loadWorkouts() async {
    isLoading = true;
    notifyListeners();
    try {
      _workouts = await _workoutRepository.getAllWorkouts();
    } catch (e) {
      print('Error loading workouts: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addWorkout(Workout workout) async {
    try {
      await _workoutRepository.addWorkout(workout);
      _workouts.add(workout);
      notifyListeners();
    } catch (e) {
      print('Error adding workout: $e');
    }
  }

  Future<void> updateWorkout(Workout workout) async {
    try {
      await _workoutRepository.updateWorkout(workout);
      final index = _workouts.indexWhere((w) => w.id == workout.id);
      if (index != -1) {
        _workouts[index] = workout;
        notifyListeners();
      }
    } catch (e) {
      print('Error updating workout: $e');
    }
  }

  Future<void> deleteWorkout(String id) async {
    try {
      await _workoutRepository.deleteWorkout(id);
      _workouts.removeWhere((w) => w.id == id);
      notifyListeners();
    } catch (e) {
      print('Error deleting workout: $e');
    }
  }

  Workout? getWorkoutById(String id) {
    try {
      final index = _workouts.indexWhere((w) => w.id == id);
      if (index == -1) return null;
      return _workouts[index];
    } catch (e) {
      print('Error getting workout by ID: $e');
      return null;
    }
  }

  List<Workout> getAllWorkouts() {
    return _workouts;
  }
}
