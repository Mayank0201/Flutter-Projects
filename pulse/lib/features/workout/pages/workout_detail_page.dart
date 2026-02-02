import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workout_provider.dart';
import '../../../core/widgets/empty_state.dart';

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
      appBar: AppBar(title: Text(workout.name)),
      body: workout.exercises.isEmpty
          ? const EmptyState(message: 'No exercises found for this workout.')
          : ListView.builder(
              itemCount: workout.exercises.length,
              itemBuilder: (context, index) {
                final exercise = workout.exercises[index];
                return Column(
                  children: [
                    ExpansionTile(
                      title: Text(exercise.name),
                      children: exercise.sets.map((set) {
                        return ListTile(
                          title: Text(
                            'Reps: ${set.reps}, Weight: ${set.weight}',
                          ),
                        );
                      }).toList(),
                    ),
                    const Divider(),
                  ],
                );
              },
            ),
    );
  }
}
