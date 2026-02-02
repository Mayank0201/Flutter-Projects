import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/workout.dart';
import '../../../data/models/exercise.dart';
import '../../../core/utils/id_generator.dart';
import '../providers/workout_provider.dart';

class AddWorkoutPage extends StatefulWidget {
  const AddWorkoutPage({super.key});

  @override
  State<AddWorkoutPage> createState() => _AddWorkoutPageState();
}

class _AddWorkoutPageState extends State<AddWorkoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final List<Exercise> _exercises = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveWorkout() async {
    if (_formKey.currentState!.validate()) {
      if (_exercises.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one exercise')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final workout = Workout(
        id: IdGenerator.generateId(),
        name: _nameController.text.trim(),
        startedAt: DateTime.now(),
        endedAt: null,
        status: WorkoutStatus.notStarted,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        exercises: _exercises,
      );

      try {
        await Provider.of<WorkoutProvider>(
          context,
          listen: false,
        ).addWorkout(workout);

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Workout created successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error creating workout: $e')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _addExercise() async {
    final newExercise = await Navigator.pushNamed(context, '/add-exercise');
    if (newExercise != null && newExercise is Exercise) {
      setState(() {
        _exercises.add(newExercise);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Workout')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Workout Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a workout name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Exercises (${_exercises.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addExercise,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Exercise'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _exercises.isEmpty
                          ? const Center(child: Text('No exercises added yet'))
                          : ListView.builder(
                              itemCount: _exercises.length,
                              itemBuilder: (context, index) {
                                final exercise = _exercises[index];
                                return Column(
                                  children: [
                                    ListTile(
                                      title: Text(exercise.name),
                                      subtitle: Text(
                                        '${exercise.sets.length} sets',
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () {
                                          setState(() {
                                            _exercises.removeAt(index);
                                          });
                                        },
                                      ),
                                    ),
                                    const Divider(),
                                  ],
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        text: 'Save Workout',
                        onPressed: _saveWorkout,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
