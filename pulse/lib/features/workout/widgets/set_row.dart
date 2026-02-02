import 'package:flutter/material.dart';
import '../../../data/models/workout_set.dart';

class SetRow extends StatelessWidget {
  final int setNumber;
  final WorkoutSet set;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const SetRow({
    super.key,
    required this.setNumber,
    required this.set,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: set.isCompleted
                    ? Colors.green.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$setNumber',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: set.isCompleted ? Colors.green : Colors.grey[700],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                children: [
                  _buildInfoItem(icon: Icons.repeat, label: '${set.reps} reps'),
                  const SizedBox(width: 24),
                  _buildInfoItem(
                    icon: Icons.fitness_center,
                    label: '${set.weight} kg',
                  ),
                ],
              ),
            ),
            if (set.isCompleted)
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[800])),
      ],
    );
  }
}
