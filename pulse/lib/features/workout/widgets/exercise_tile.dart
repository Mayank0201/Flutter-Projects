import 'package:flutter/material.dart';
import '../../../data/models/exercise.dart';
import 'set_row.dart';

class ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback? onDelete;
  final VoidCallback? onAddSet;
  final Function(int)? onDeleteSet;
  final bool isExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  const ExerciseTile({
    super.key,
    required this.exercise,
    this.onDelete,
    this.onAddSet,
    this.onDeleteSet,
    this.isExpanded = false,
    this.onExpansionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        initiallyExpanded: isExpanded,
        onExpansionChanged: onExpansionChanged,
        title: Text(
          exercise.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${exercise.sets.length} sets',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete,
              ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          if (exercise.sets.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No sets added yet'),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: exercise.sets.length,
              itemBuilder: (context, index) {
                final set = exercise.sets[index];
                return SetRow(
                  setNumber: index + 1,
                  set: set,
                  onDelete: onDeleteSet != null
                      ? () => onDeleteSet!(index)
                      : null,
                );
              },
            ),
          if (onAddSet != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton.icon(
                onPressed: onAddSet,
                icon: const Icon(Icons.add),
                label: const Text('Add Set'),
              ),
            ),
        ],
      ),
    );
  }
}
