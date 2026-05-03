import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../provider/wishlist_provider.dart';
import '../../../model/watchlist_item_model.dart';
import '../widgets/status_picker_sheet.dart';
import 'movie_details_page.dart';

const _statusOptions = ['ALL', 'PENDING', 'ACTIVE', 'COMPLETED'];

const _statusMeta = {
  'ALL': (label: 'All', icon: Icons.list_alt_rounded, color: Colors.blueGrey),
  'PENDING': (
    label: 'Pending',
    icon: Icons.bookmark_outline_rounded,
    color: Colors.amber
  ),
  'ACTIVE': (
    label: 'Watching',
    icon: Icons.play_circle_outline_rounded,
    color: Colors.blue
  ),
  'COMPLETED': (
    label: 'Completed',
    icon: Icons.check_circle_outline_rounded,
    color: Colors.green
  ),
};

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WishlistProvider>().loadWatchlist();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishlistProvider>();
    final wishlist = provider.getWishlist;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchlist'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _StatusFilterBar(provider: provider),
        ),
      ),
      body: _buildBody(provider, wishlist, theme, colorScheme),
    );
  }

  Widget _buildBody(
    WishlistProvider provider,
    List<WatchlistItem> wishlist,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (provider.isLoading && wishlist.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && wishlist.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: colorScheme.error.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 14),
              Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => provider.loadWatchlist(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (wishlist.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.movie_filter_outlined,
              size: 56,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              provider.activeStatusFilter == null
                  ? 'No movies yet'
                  : 'No ${provider.activeStatusFilter!.toLowerCase()} movies',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Add movies from the home screen',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadWatchlist,
      color: colorScheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: wishlist.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) =>
            _WatchlistCard(item: wishlist[index], provider: provider),
      ),
    );
  }
}

// ── Status filter chip bar ─────────────────────────────────────────────────

class _StatusFilterBar extends StatelessWidget {
  final WishlistProvider provider;
  const _StatusFilterBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = provider.activeStatusFilter;

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: _statusOptions.map((s) {
          final isAll = s == 'ALL';
          final isSelected = isAll ? active == null : active == s;
          final meta = _statusMeta[s]!;
          final chipColor = meta.color;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(meta.label),
              avatar: Icon(meta.icon, size: 16),
              selected: isSelected,
              onSelected: (_) {
                provider.setStatusFilter(isAll ? null : s);
              },
              selectedColor: chipColor.withValues(alpha: 0.18),
              checkmarkColor: chipColor,
              avatarBoxConstraints: const BoxConstraints(maxWidth: 28),
              labelStyle: TextStyle(
                color: isSelected ? chipColor : colorScheme.onSurface,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
              side: BorderSide(
                color: isSelected
                    ? chipColor.withValues(alpha: 0.5)
                    : colorScheme.outline.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Watchlist card ─────────────────────────────────────────────────────────

class _WatchlistCard extends StatelessWidget {
  final WatchlistItem item;
  final WishlistProvider provider;

  const _WatchlistCard({required this.item, required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPending = provider.isPending(item.movieId);

    final subtitle = [
      if (item.releaseYear != null) item.releaseYear.toString(),
      item.genre,
    ].join(' • ');

    final meta = _statusMeta[item.status] ?? _statusMeta['PENDING']!;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MovieDetailsPage(movie: item.toMovie()),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // Poster
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: item.posterUrl.isNotEmpty
                    ? Image.network(
                        item.posterUrl,
                        width: 56,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _posterPlaceholder(colorScheme),
                      )
                    : _posterPlaceholder(colorScheme),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                    const SizedBox(height: 8),
                    _StatusBadge(meta: meta),
                  ],
                ),
              ),
              // Actions
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  isPending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          tooltip: 'Change status',
                          icon: Icon(meta.icon,
                              color: meta.color, size: 22),
                          onPressed: () => _showStatusPicker(
                              context, item, provider),
                        ),
                  IconButton(
                    onPressed: isPending
                        ? null
                        : () async {
                            final ok = await provider
                                .removeMovieById(item.movieId);
                            if (!context.mounted) return;
                            if (!ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Failed to remove movie.')),
                              );
                            }
                          },
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: colorScheme.error.withValues(alpha: 0.7),
                      size: 22,
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

  Widget _posterPlaceholder(ColorScheme cs) => Container(
        width: 56,
        height: 80,
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.movie_rounded, color: cs.onSurfaceVariant),
      );

  void _showStatusPicker(
    BuildContext context,
    WatchlistItem item,
    WishlistProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatusPickerSheet(
        movie: item.toMovie(),
        provider: provider,
        currentStatus: item.status,
      ),
    );
  }
}

// ── Status badge ───────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final ({String label, IconData icon, Color color}) meta;

  const _StatusBadge({required this.meta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: meta.color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 12, color: meta.color),
          const SizedBox(width: 4),
          Text(
            meta.label,
            style: TextStyle(
              fontSize: 11,
              color: meta.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
