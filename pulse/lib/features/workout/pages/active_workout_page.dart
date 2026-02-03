import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/workout.dart';
import '../../../data/models/exercise.dart';
import '../../../data/models/workout_set.dart';
import '../providers/workout_provider.dart';
import '../widgets/workout_timer.dart';

class ActiveWorkoutPage extends StatefulWidget {
  const ActiveWorkoutPage({super.key});

  @override
  State<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends State<ActiveWorkoutPage> {
  bool _showRestTimer = false;
  int _restDuration = 60; // Default 60 seconds rest

  @override
  Widget build(BuildContext context) {
    final workoutId = ModalRoute.of(context)!.settings.arguments as String;
    final workoutProvider = Provider.of<WorkoutProvider>(context);
    final workout = workoutProvider.getWorkoutById(workoutId);

    if (workout == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Active Workout')),
        body: const Center(child: Text('Workout not found.')),
      );
    }

    return WillPopScope(
      onWillPop: () => _showExitConfirmation(context, workout, workoutProvider),
      child: Scaffold(
        appBar: AppBar(
          title: Text(workout.name),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.check_circle),
              tooltip: 'Complete Workout',
              onPressed: () =>
                  _completeWorkout(context, workout, workoutProvider),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // Timer Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'WORKOUT TIME',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      WorkoutTimer(
                        startTime: workout.startedAt,
                        isRunning: workout.status == WorkoutStatus.inProgress,
                        textStyle: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStatChip(
                            Icons.fitness_center,
                            '${workout.exercises.length} exercises',
                          ),
                          const SizedBox(width: 16),
                          _buildStatChip(
                            Icons.check_circle_outline,
                            '${_getCompletedSetsCount(workout)}/${_getTotalSetsCount(workout)} sets',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Rest Duration Selector
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'Rest Duration: ',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 30, label: Text('30s')),
                          ButtonSegment(value: 60, label: Text('60s')),
                          ButtonSegment(value: 90, label: Text('90s')),
                          ButtonSegment(value: 120, label: Text('2m')),
                        ],
                        selected: {_restDuration},
                        onSelectionChanged: (values) {
                          setState(() {
                            _restDuration = values.first;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Exercises List
                Expanded(
                  child: workout.exercises.isEmpty
                      ? const Center(
                          child: Text(
                            'No exercises in this workout',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 100),
                          itemCount: workout.exercises.length,
                          itemBuilder: (context, exerciseIndex) {
                            final exercise = workout.exercises[exerciseIndex];
                            return _buildExerciseCard(
                              exercise,
                              exerciseIndex,
                              workout,
                              workoutProvider,
                            );
                          },
                        ),
                ),
              ],
            ),
            // Rest Timer Overlay
            if (_showRestTimer)
              Container(
                color: Colors.black54,
                child: Center(
                  child: RestTimer(
                    restDurationSeconds: _restDuration,
                    onComplete: () {
                      setState(() {
                        _showRestTimer = false;
                      });
                    },
                    onSkip: () {
                      setState(() {
                        _showRestTimer = false;
                      });
                    },
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(context, workout, workoutProvider),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(
    Exercise exercise,
    int exerciseIndex,
    Workout workout,
    WorkoutProvider provider,
  ) {
    final allSetsCompleted =
        exercise.sets.isNotEmpty && exercise.sets.every((s) => s.isCompleted);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: allSetsCompleted ? Colors.green : Colors.blue,
              child: allSetsCompleted
                  ? const Icon(Icons.check, color: Colors.white)
                  : Text(
                      '${exerciseIndex + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            title: Text(
              exercise.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: allSetsCompleted
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            subtitle: Text(
              '${exercise.muscleGroup} • ${exercise.sets.length} sets',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          if (exercise.sets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                children: [
                  // Header Row
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            'SET',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              'REPS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              'KG',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 60),
                      ],
                    ),
                  ),
                  // Set Rows
                  ...exercise.sets.asMap().entries.map((entry) {
                    final setIndex = entry.key;
                    final set = entry.value;
                    return _buildSetRow(
                      set,
                      setIndex,
                      exerciseIndex,
                      workout,
                      provider,
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSetRow(
    WorkoutSet set,
    int setIndex,
    int exerciseIndex,
    Workout workout,
    WorkoutProvider provider,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: set.isCompleted
            ? Colors.green.withOpacity(0.1)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: set.isCompleted
                  ? Colors.green
                  : Colors.grey.shade300,
              child: Text(
                '${setIndex + 1}',
                style: TextStyle(
                  fontSize: 12,
                  color: set.isCompleted ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                '${set.reps}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                '${set.weight}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: ElevatedButton(
              onPressed: set.isCompleted
                  ? null
                  : () => _completeSet(
                      exerciseIndex,
                      setIndex,
                      workout,
                      provider,
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: set.isCompleted ? Colors.grey : Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(50, 32),
              ),
              child: Icon(
                set.isCompleted ? Icons.check : Icons.done,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    Workout workout,
    WorkoutProvider provider,
  ) {
    final isPaused = workout.status == WorkoutStatus.paused;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _togglePause(workout, provider),
              icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
              label: Text(isPaused ? 'Resume' : 'Pause'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPaused ? Colors.green : Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _completeWorkout(context, workout, provider),
              icon: const Icon(Icons.check_circle),
              label: const Text('Finish'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _getCompletedSetsCount(Workout workout) {
    return workout.exercises.fold(
      0,
      (sum, ex) => sum + ex.sets.where((s) => s.isCompleted).length,
    );
  }

  int _getTotalSetsCount(Workout workout) {
    return workout.exercises.fold(0, (sum, ex) => sum + ex.sets.length);
  }

  Future<void> _completeSet(
    int exerciseIndex,
    int setIndex,
    Workout workout,
    WorkoutProvider provider,
  ) async {
    final exercises = workout.exercises.map((e) => e).toList();
    final exercise = exercises[exerciseIndex];
    final sets = exercise.sets.map((s) => s).toList();

    // Mark the set as completed
    sets[setIndex] = WorkoutSet(
      id: sets[setIndex].id,
      reps: sets[setIndex].reps,
      weight: sets[setIndex].weight,
      performedAt: DateTime.now(),
      isCompleted: true,
    );

    // Update the exercise with new sets
    exercises[exerciseIndex] = Exercise(
      id: exercise.id,
      name: exercise.name,
      muscleGroup: exercise.muscleGroup,
      orderIndex: exercise.orderIndex,
      sets: sets,
    );

    // Update the workout
    final updatedWorkout = Workout(
      id: workout.id,
      name: workout.name,
      startedAt: workout.startedAt,
      endedAt: workout.endedAt,
      status: workout.status,
      notes: workout.notes,
      exercises: exercises,
    );

    await provider.updateWorkout(updatedWorkout);

    // Show rest timer
    setState(() {
      _showRestTimer = true;
    });
  }

  Future<void> _togglePause(Workout workout, WorkoutProvider provider) async {
    final newStatus = workout.status == WorkoutStatus.paused
        ? WorkoutStatus.inProgress
        : WorkoutStatus.paused;

    final updatedWorkout = Workout(
      id: workout.id,
      name: workout.name,
      startedAt: workout.startedAt,
      endedAt: workout.endedAt,
      status: newStatus,
      notes: workout.notes,
      exercises: workout.exercises,
    );

    await provider.updateWorkout(updatedWorkout);
  }

  Future<void> _completeWorkout(
    BuildContext context,
    Workout workout,
    WorkoutProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Workout?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getCompletedSetsCount(workout)}/${_getTotalSetsCount(workout)} sets completed',
            ),
            const SizedBox(height: 8),
            const Text('Are you sure you want to finish this workout?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final updatedWorkout = Workout(
        id: workout.id,
        name: workout.name,
        startedAt: workout.startedAt,
        endedAt: DateTime.now(),
        status: WorkoutStatus.completed,
        notes: workout.notes,
        exercises: workout.exercises,
      );

      await provider.updateWorkout(updatedWorkout);

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Workout completed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<bool> _showExitConfirmation(
    BuildContext context,
    Workout workout,
    WorkoutProvider provider,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Workout?'),
        content: const Text('What would you like to do with this workout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Continue Workout'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'pause'),
            child: const Text('Pause & Exit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'complete'),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (result == 'pause') {
      final updatedWorkout = Workout(
        id: workout.id,
        name: workout.name,
        startedAt: workout.startedAt,
        endedAt: workout.endedAt,
        status: WorkoutStatus.paused,
        notes: workout.notes,
        exercises: workout.exercises,
      );
      await provider.updateWorkout(updatedWorkout);
      return true;
    } else if (result == 'complete') {
      await _completeWorkout(context, workout, provider);
      return false;
    }

    return result == 'cancel' ? false : false;
  }
}
