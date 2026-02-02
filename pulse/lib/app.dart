import 'package:flutter/material.dart';
import 'package:pulse/features/workout/pages/workout_list_page.dart';
import 'package:pulse/features/workout/pages/add_workout_page.dart';
import 'package:pulse/features/workout/pages/workout_detail_page.dart';
import 'package:pulse/features/workout/pages/add_exercise_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pulse Workout Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const WorkoutListPage(),
      routes: {
        '/workouts': (context) => const WorkoutListPage(),
        '/add-workout': (context) => const AddWorkoutPage(),
        '/workout-detail': (context) => const WorkoutDetailPage(),
        '/add-exercise': (context) => const AddExercisePage(),
      },
    );
  }
}
