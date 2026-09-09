import 'package:flutter/material.dart';

import '../../../model/show_model.dart';
import '../../../service/show_service.dart';
import 'poster_image.dart';
import '../pages/show_details_page.dart';

// the row of shows you are partway through. the backend already knows the next
// episode for each one, so this only reads.
class ContinueWatchingRow extends StatefulWidget {
  const ContinueWatchingRow({super.key});

  @override
  State<ContinueWatchingRow> createState() => ContinueWatchingRowState();
}

const double _cardWidth = 118;
const double _posterHeight = 150;
const double _rowHeight = 208;

class ContinueWatchingRowState extends State<ContinueWatchingRow> {
  final ShowService _service = ShowService();

  List<ShowProgress> _shows = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  // public so the home page can refresh this after the user marks something
  Future<void> reload() async {
    try {
      final shows = await _service.getContinueWatching();
      if (!mounted) return;
      setState(() {
        _shows = shows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // hold the height on first load so the home screen does not jump,
    // but stay out of the way once we know there is nothing in progress
    if (!_loading && _shows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Text(
            "Continue watching",
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: _rowHeight,
          child: _loading
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 4,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, _) => _skeletonCard(),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _shows.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _card(_shows[i]),
                ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _skeletonCard() {
    return const SizedBox(
      width: _cardWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: _cardWidth, height: _posterHeight),
          SizedBox(height: 7),
          SkeletonBox(width: 92, height: 11, radius: 4),
          SizedBox(height: 6),
          SkeletonBox(width: 56, height: 10, radius: 4),
        ],
      ),
    );
  }

  Widget _card(ShowProgress show) {
    final theme = Theme.of(context);

    return SizedBox(
      width: _cardWidth,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ShowDetailsPage(
                showTmdbId: show.tmdbId,
                initialTitle: show.title,
              ),
            ),
          );
          // progress probably moved while they were in there
          reload();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PosterImage(
              url: show.posterUrl,
              width: _cardWidth,
              height: _posterHeight,
              radius: 10,
            ),
            const SizedBox(height: 7),
            Text(
              show.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              show.nextLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: show.totalEpisodes == 0
                    ? 0
                    : show.episodesWatched / show.totalEpisodes,
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
