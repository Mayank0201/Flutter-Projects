import 'package:flutter/material.dart';
import 'app.dart';
import 'package:provider/provider.dart';
import 'features/workout/providers/workout_provider.dart';
import 'data/local/hive_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await HiveInitializer.initializeHive();
  await HiveInitializer.openBoxes();

  runApp(
    ChangeNotifierProvider(
      create: (context) => WorkoutProvider()..loadWorkouts(),
      child: const App(),
    ),
  );
}
