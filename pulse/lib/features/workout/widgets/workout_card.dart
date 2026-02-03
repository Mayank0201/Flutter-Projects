import 'package:flutter/material.dart';
import '../../../data/models/workout.dart';

class WorkoutCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onStart;
  final VoidCallback? onResume;

  const WorkoutCard({
    super.key,
    required this.workout,
    this.onTap,
    this.onDelete,
    this.onStart,
    this.onResume,
  });

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDuration(DateTime start, DateTime? end) {
    final endTime = end ?? DateTime.now();
    final duration = endTime.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String _getStatusText(WorkoutStatus status) {
    switch (status) {
      case WorkoutStatus.notStarted:
        return 'Not Started';
      case WorkoutStatus.inProgress:
        return 'In Progress';
      case WorkoutStatus.completed:
        return 'Completed';
      case WorkoutStatus.paused:
        return 'Paused';
    }
  }

  Color _getStatusColor(WorkoutStatus status) {
    switch (status) {
      case WorkoutStatus.notStarted:
        return Colors.grey;
      case WorkoutStatus.inProgress:
        return Colors.blue;
      case WorkoutStatus.completed:
        return Colors.green;
      case WorkoutStatus.paused:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(WorkoutStatus status) {
    switch (status) {
      case WorkoutStatus.notStarted:
        return Icons.schedule;
      case WorkoutStatus.inProgress:
        return Icons.play_circle_filled;
      case WorkoutStatus.completed:
        return Icons.check_circle;
      case WorkoutStatus.paused:
        return Icons.pause_circle_filled;
    }
  }

  int _getTotalSets() {
    return workout.exercises.fold(0, (sum, ex) => sum + ex.sets.length);
  }

  int _getCompletedSets() {
    return workout.exercises.fold(
      0,
      (sum, ex) => sum + ex.sets.where((s) => s.isCompleted).length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = workout.status == WorkoutStatus.inProgress;
    final isPaused = workout.status == WorkoutStatus.paused;
    final isCompleted = workout.status == WorkoutStatus.completed;
    final totalSets = _getTotalSets();
    final completedSets = _getCompletedSets();
    final progress = totalSets > 0 ? completedSets / totalSets : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isActive ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive
            ? BorderSide(color: Colors.blue.shade400, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(workout.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getStatusIcon(workout.status),
                      color: _getStatusColor(workout.status),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workout.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(workout.startedAt),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onDelete != null && !isActive)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: onDelete,
                      tooltip: 'Delete',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Stats Row
              Row(
                children: [
                  _buildStatItem(
                    Icons.fitness_center,
                    '${workout.exercises.length} exercises',
                  ),
                  const SizedBox(width: 16),
                  _buildStatItem(
                    Icons.repeat,
                    '$completedSets/$totalSets sets',
                  ),
                  if (isCompleted && workout.endedAt != null) ...[
                    const SizedBox(width: 16),
                    _buildStatItem(
                      Icons.timer,
                      _formatDuration(workout.startedAt, workout.endedAt),
                    ),
                  ],
                ],
              ),
              // Progress Bar (for in-progress or paused workouts)
              if ((isActive || isPaused) && totalSets > 0) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isActive ? Colors.blue : Colors.orange,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Status and Action Button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(workout.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(workout.status),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(workout.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (workout.status == WorkoutStatus.notStarted &&
                      onStart != null)
                    ElevatedButton.icon(
                      onPressed: onStart,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  if ((isActive || isPaused) && onResume != null)
                    ElevatedButton.icon(
                      onPressed: onResume,
                      icon: Icon(
                        isActive ? Icons.open_in_new : Icons.play_arrow,
                        size: 18,
                      ),
                      label: Text(isActive ? 'Continue' : 'Resume'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isActive ? Colors.blue : Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
