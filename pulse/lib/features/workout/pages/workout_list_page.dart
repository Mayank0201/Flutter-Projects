import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/workout.dart';
import '../providers/workout_provider.dart';
import '../widgets/workout_card.dart';

class WorkoutListPage extends StatelessWidget {
  const WorkoutListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final workoutProvider = Provider.of<WorkoutProvider>(context);
    final workouts = workoutProvider.workouts;
    bool isLoading = workoutProvider.loading;

    // Sort workouts: active first, then paused, then by date
    final sortedWorkouts = List<Workout>.from(workouts)
      ..sort((a, b) {
        // Active workouts first
        if (a.status == WorkoutStatus.inProgress &&
            b.status != WorkoutStatus.inProgress)
          return -1;
        if (b.status == WorkoutStatus.inProgress &&
            a.status != WorkoutStatus.inProgress)
          return 1;
        // Then paused
        if (a.status == WorkoutStatus.paused &&
            b.status != WorkoutStatus.paused)
          return -1;
        if (b.status == WorkoutStatus.paused &&
            a.status != WorkoutStatus.paused)
          return 1;
        // Then by date (newest first)
        return b.startedAt.compareTo(a.startedAt);
      });

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Workouts')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Workouts'),
        actions: [
          if (workouts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.bar_chart),
              tooltip: 'Stats',
              onPressed: () => _showQuickStats(context, workouts),
            ),
        ],
      ),
      body: workouts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No workouts yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button to create your first workout',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/add-workout'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Workout'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: sortedWorkouts.length,
              itemBuilder: (context, index) {
                final workout = sortedWorkouts[index];
                return WorkoutCard(
                  workout: workout,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/workout-detail',
                      arguments: workout.id,
                    );
                  },
                  onDelete: () => _showDeleteConfirmation(
                    context,
                    workoutProvider,
                    workout.id,
                    workout.name,
                  ),
                  onStart: () => _showStartWorkoutDialog(
                    context,
                    workout,
                    workoutProvider,
                  ),
                  onResume: () {
                    Navigator.pushNamed(
                      context,
                      '/active-workout',
                      arguments: workout.id,
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/add-workout'),
        icon: const Icon(Icons.add),
        label: const Text('New Workout'),
      ),
    );
  }

  void _showStartWorkoutDialog(
    BuildContext context,
    Workout workout,
    WorkoutProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.play_circle_filled, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Text('Start ${workout.name}?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${workout.exercises.length} exercises'),
            const SizedBox(height: 4),
            Text(
              '${workout.exercises.fold(0, (sum, ex) => sum + ex.sets.length)} total sets',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'The timer will start once you begin the workout.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _startWorkout(context, workout, provider);
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Workout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startWorkout(
    BuildContext context,
    Workout workout,
    WorkoutProvider provider,
  ) async {
    // Update workout status to in-progress and reset start time
    final updatedWorkout = Workout(
      id: workout.id,
      name: workout.name,
      startedAt: DateTime.now(),
      endedAt: null,
      status: WorkoutStatus.inProgress,
      notes: workout.notes,
      exercises: workout.exercises,
    );

    await provider.updateWorkout(updatedWorkout);

    if (context.mounted) {
      Navigator.pushNamed(context, '/active-workout', arguments: workout.id);
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WorkoutProvider provider,
    String workoutId,
    String workoutName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workout'),
        content: Text('Are you sure you want to delete "$workoutName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await provider.deleteWorkout(workoutId);
              if (context.mounted) {
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

  void _showQuickStats(BuildContext context, List<Workout> workouts) {
    final completedWorkouts = workouts
        .where((w) => w.status == WorkoutStatus.completed)
        .length;
    final totalExercises = workouts.fold(
      0,
      (sum, w) => sum + w.exercises.length,
    );
    final totalSets = workouts.fold(
      0,
      (sum, w) => sum + w.exercises.fold(0, (s, e) => s + e.sets.length),
    );
    final completedSets = workouts.fold(
      0,
      (sum, w) =>
          sum +
          w.exercises.fold(
            0,
            (s, e) => s + e.sets.where((set) => set.isCompleted).length,
          ),
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Quick Stats',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  'Total\nWorkouts',
                  '${workouts.length}',
                  Icons.fitness_center,
                ),
                _buildStatColumn(
                  'Completed',
                  '$completedWorkouts',
                  Icons.check_circle,
                ),
                _buildStatColumn('Exercises', '$totalExercises', Icons.list),
                _buildStatColumn(
                  'Sets Done',
                  '$completedSets/$totalSets',
                  Icons.repeat,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Colors.blue),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
