import 'package:flutter/material.dart';
import '../../../model/movie_model.dart';
import '../../../provider/wishlist_provider.dart';

const statusColors = <String, Color>{
  'PENDING': Colors.amber,
  'ACTIVE': Colors.blue,
  'COMPLETED': Colors.green,
};

const statusIcons = <String, IconData>{
  'PENDING': Icons.bookmark_outline_rounded,
  'ACTIVE': Icons.play_circle_outline_rounded,
  'COMPLETED': Icons.check_circle_outline_rounded,
};

const statusLabels = <String, String>{
  'PENDING': 'Pending',
  'ACTIVE': 'Watching',
  'COMPLETED': 'Completed',
};

/// Bottom-sheet that lets the user cycle through PENDING / ACTIVE / COMPLETED.
class StatusPickerSheet extends StatelessWidget {
  final Movie movie;
  final WishlistProvider provider;
  final String? currentStatus;

  const StatusPickerSheet({
    super.key,
    required this.movie,
    required this.provider,
    this.currentStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentStatus == null ? 'Add to List' : 'Update Status',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              movie.title,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ...['PENDING', 'ACTIVE', 'COMPLETED'].map((s) {
              final color = statusColors[s]!;
              final icon = statusIcons[s]!;
              final label = statusLabels[s]!;
              final isSelected = currentStatus == s;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                title: Text(
                  label,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? color : null,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_rounded, color: color)
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  if (isSelected) return;

                  bool success;
                  if (currentStatus == null) {
                    // Movie not in watchlist, add it first
                    success = await provider.addMovie(movie);
                    if (success) {
                      // Then update status
                      success = await provider.updateStatus(movie.id, s);
                    }
                  } else {
                    success = await provider.updateStatus(movie.id, s);
                  }

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          success ? 'Status updated to $label' : 'Failed to update status'),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
