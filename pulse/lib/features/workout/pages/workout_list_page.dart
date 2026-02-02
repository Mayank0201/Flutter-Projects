import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workout_provider.dart';

class WorkoutListPage extends StatelessWidget {
  const WorkoutListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final workoutProvider = Provider.of<WorkoutProvider>(context);
    final workouts = workoutProvider.workouts;
    bool isLoading = workoutProvider.loading;

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Workouts')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      body: workouts.isEmpty
          ? const Center(
              child: Text(
                'No workouts available. Please add a workout.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              itemCount: workouts.length,
              itemBuilder: (context, index) {
                final workout = workouts[index];
                return ListTile(
                  title: Text(workout.name),
                  subtitle: Text('${workout.exercises.length} exercises'),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/workout-detail',
                      arguments: workout.id,
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add-workout');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
