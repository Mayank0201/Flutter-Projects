import 'package:flutter/material.dart';
import '../../../data/models/exercise.dart';
import '../../../data/models/workout_set.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/widgets/primary_button.dart';

class AddExercisePage extends StatefulWidget {
  const AddExercisePage({super.key});

  @override
  State<AddExercisePage> createState() => _AddExercisePageState();
}

class _AddExercisePageState extends State<AddExercisePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedMuscleGroup = 'Chest';
  final List<WorkoutSet> _sets = [];

  final List<String> _muscleGroups = [
    'Chest',
    'Back',
    'Shoulders',
    'Biceps',
    'Triceps',
    'Legs',
    'Abs',
    'Glutes',
    'Calves',
    'Forearms',
    'Full Body',
    'Cardio',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addSet() {
    showDialog(
      context: context,
      builder: (context) => _AddSetDialog(
        onAdd: (reps, weight) {
          setState(() {
            _sets.add(
              WorkoutSet(
                id: IdGenerator.generateId(),
                reps: reps,
                weight: weight,
                performedAt: DateTime.now(),
                isCompleted: false,
              ),
            );
          });
        },
      ),
    );
  }

  void _removeSet(int index) {
    setState(() {
      _sets.removeAt(index);
    });
  }

  void _saveExercise() {
    if (_formKey.currentState!.validate()) {
      if (_sets.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one set')),
        );
        return;
      }

      final exercise = Exercise(
        id: IdGenerator.generateId(),
        name: _nameController.text.trim(),
        muscleGroup: _selectedMuscleGroup,
        orderIndex: 0, // Will be updated when added to workout
        sets: _sets,
      );

      Navigator.of(context).pop(exercise);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Exercise')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Exercise Name',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Bench Press',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an exercise name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedMuscleGroup,
                decoration: const InputDecoration(
                  labelText: 'Muscle Group',
                  border: OutlineInputBorder(),
                ),
                items: _muscleGroups.map((group) {
                  return DropdownMenuItem(value: group, child: Text(group));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedMuscleGroup = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sets (${_sets.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addSet,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Set'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _sets.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fitness_center,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No sets added yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                            Text(
                              'Tap "Add Set" to add reps and weight',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _sets.length,
                        itemBuilder: (context, index) {
                          final set = _sets[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text('${index + 1}'),
                              ),
                              title: Text(
                                '${set.reps} reps × ${set.weight} kg',
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeSet(index),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  text: 'Save Exercise',
                  onPressed: _saveExercise,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddSetDialog extends StatefulWidget {
  final Function(int reps, double weight) onAdd;

  const _AddSetDialog({required this.onAdd});

  @override
  State<_AddSetDialog> createState() => _AddSetDialogState();
}

class _AddSetDialogState extends State<_AddSetDialog> {
  final _repsController = TextEditingController(text: '10');
  final _weightController = TextEditingController(text: '0');

  @override
  void dispose() {
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Set'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _repsController,
            decoration: const InputDecoration(
              labelText: 'Reps',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _weightController,
            decoration: const InputDecoration(
              labelText: 'Weight (kg)',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final reps = int.tryParse(_repsController.text) ?? 0;
            final weight = double.tryParse(_weightController.text) ?? 0.0;

            if (reps <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter valid reps')),
              );
              return;
            }

            widget.onAdd(reps, weight);
            Navigator.of(context).pop();
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
