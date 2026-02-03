import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workout_provider.dart';
import '../widgets/exercise_tile.dart';
import '../../../data/models/workout.dart';
import '../../../data/models/exercise.dart';

class WorkoutDetailPage extends StatelessWidget {
  const WorkoutDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final workoutId = ModalRoute.of(context)!.settings.arguments as String;
    final workoutProvider = Provider.of<WorkoutProvider>(context);
    final workout = workoutProvider.getWorkoutById(workoutId);

    if (workout == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout Details')),
        body: const Center(child: Text('Workout not found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(workout.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) =>
                _handleMenuAction(context, value, workout, workoutProvider),
            itemBuilder: (context) => [
              if (workout.status == WorkoutStatus.notStarted)
                const PopupMenuItem(
                  value: 'start',
                  child: Text('Start Workout'),
                ),
              if (workout.status == WorkoutStatus.inProgress)
                const PopupMenuItem(
                  value: 'complete',
                  child: Text('Complete Workout'),
                ),
              if (workout.status == WorkoutStatus.inProgress)
                const PopupMenuItem(
                  value: 'pause',
                  child: Text('Pause Workout'),
                ),
              if (workout.status == WorkoutStatus.paused)
                const PopupMenuItem(
                  value: 'resume',
                  child: Text('Resume Workout'),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete Workout'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWorkoutInfo(workout),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Exercises (${workout.exercises.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      _addExercise(context, workout, workoutProvider),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child: workout.exercises.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.fitness_center,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No exercises yet',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap "Add" to add exercises',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: workout.exercises.length,
                    itemBuilder: (context, index) {
                      final exercise = workout.exercises[index];
                      return ExerciseTile(
                        exercise: exercise,
                        onDelete: () => _deleteExercise(
                          context,
                          workout,
                          index,
                          workoutProvider,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutInfo(Workout workout) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatusChip(workout.status),
              const Spacer(),
              Text(
                _formatDate(workout.startedAt),
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          if (workout.notes != null && workout.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              workout.notes!,
              style: const TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(WorkoutStatus status) {
    Color color;
    String label;
    switch (status) {
      case WorkoutStatus.notStarted:
        color = Colors.grey;
        label = 'Not Started';
        break;
      case WorkoutStatus.inProgress:
        color = Colors.blue;
        label = 'In Progress';
        break;
      case WorkoutStatus.completed:
        color = Colors.green;
        label = 'Completed';
        break;
      case WorkoutStatus.paused:
        color = Colors.orange;
        label = 'Paused';
        break;
    }
    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    String action,
    Workout workout,
    WorkoutProvider provider,
  ) async {
    switch (action) {
      case 'start':
        await _updateWorkoutStatus(
          context,
          workout,
          WorkoutStatus.inProgress,
          provider,
        );
        break;
      case 'complete':
        await _updateWorkoutStatus(
          context,
          workout,
          WorkoutStatus.completed,
          provider,
        );
        break;
      case 'pause':
        await _updateWorkoutStatus(
          context,
          workout,
          WorkoutStatus.paused,
          provider,
        );
        break;
      case 'resume':
        await _updateWorkoutStatus(
          context,
          workout,
          WorkoutStatus.inProgress,
          provider,
        );
        break;
      case 'delete':
        _showDeleteConfirmation(context, workout, provider);
        break;
    }
  }

  Future<void> _updateWorkoutStatus(
    BuildContext context,
    Workout workout,
    WorkoutStatus newStatus,
    WorkoutProvider provider,
  ) async {
    final updatedWorkout = Workout(
      id: workout.id,
      name: workout.name,
      startedAt: workout.startedAt,
      endedAt: newStatus == WorkoutStatus.completed
          ? DateTime.now()
          : workout.endedAt,
      status: newStatus,
      notes: workout.notes,
      exercises: workout.exercises,
    );
    await provider.updateWorkout(updatedWorkout);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Workout status updated to ${newStatus.name}')),
      );
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    Workout workout,
    WorkoutProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workout'),
        content: Text('Are you sure you want to delete "${workout.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await provider.deleteWorkout(workout.id);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Workout deleted')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _addExercise(
    BuildContext context,
    Workout workout,
    WorkoutProvider provider,
  ) async {
    final newExercise = await Navigator.pushNamed(context, '/add-exercise');
    if (newExercise != null && newExercise is Exercise) {
      final updatedExercises = [...workout.exercises, newExercise];
      final updatedWorkout = Workout(
        id: workout.id,
        name: workout.name,
        startedAt: workout.startedAt,
        endedAt: workout.endedAt,
        status: workout.status,
        notes: workout.notes,
        exercises: updatedExercises,
      );
      await provider.updateWorkout(updatedWorkout);
    }
  }

  Future<void> _deleteExercise(
    BuildContext context,
    Workout workout,
    int exerciseIndex,
    WorkoutProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Exercise'),
        content: Text(
          'Are you sure you want to delete "${workout.exercises[exerciseIndex].name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final updatedExercises = [...workout.exercises];
      updatedExercises.removeAt(exerciseIndex);
      final updatedWorkout = Workout(
        id: workout.id,
        name: workout.name,
        startedAt: workout.startedAt,
        endedAt: workout.endedAt,
        status: workout.status,
        notes: workout.notes,
        exercises: updatedExercises,
      );
      await provider.updateWorkout(updatedWorkout);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Exercise deleted')));
      }
    }
  }
}
