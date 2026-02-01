import '../../../data/models/workout.dart';

class WorkoutCalculations {
  static int calculateTotalReps(Workout workout) {
    int totalReps = 0;
    for (var exercise in workout.exercises) {
      for (var set in exercise.sets) {
        totalReps += set.reps;
      }
    }
    return totalReps;
  }

  static double calculateTotalVolume(Workout workout) {
    double totalVolume = 0;
    for (var exercise in workout.exercises) {
      for (var set in exercise.sets) {
        totalVolume += set.reps * set.weight;
      }
    }
    return totalVolume;
  }

  static Duration calculateWorkoutDuration(Workout workout) {
    if (workout.endedAt != null) {
      return workout.endedAt!.difference(workout.startedAt);
    }
    return Duration.zero;
  }

  static double calculatePersonalRecord(Workout workout, String exerciseName) {
    double maxWeight = 0;
    for (var exercise in workout.exercises) {
      if (exercise.name == exerciseName) {
        for (var set in exercise.sets) {
          if (set.weight > maxWeight) {
            maxWeight = set.weight;
          }
        }
      }
    }
    return maxWeight;
  }
}
