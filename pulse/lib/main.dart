import 'package:flutter/material.dart';
import 'app.dart';
import 'package:provider/provider.dart';
import 'features/workout/providers/workout_provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => WorkoutProvider(),
      child: const App(),
    ),
  );
}
