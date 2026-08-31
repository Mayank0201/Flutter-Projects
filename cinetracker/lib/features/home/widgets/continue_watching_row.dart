import 'package:flutter/material.dart';

import '../../../model/show_model.dart';
import '../../../service/show_service.dart';
import '../pages/show_details_page.dart';

// the row of shows you are partway through. the backend already knows the next
// episode for each one, so this only reads.
class ContinueWatchingRow extends StatefulWidget {
  const ContinueWatchingRow({super.key});

  @override
  State<ContinueWatchingRow> createState() => ContinueWatchingRowState();
}

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
    // nothing in progress yet, so do not take up space
    if (_loading || _shows.isEmpty) return const SizedBox.shrink();

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
          height: 208,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _shows.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _card(_shows[i]),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _card(ShowProgress show) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 118,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: show.posterUrl != null
                  ? Image.network(
                      show.posterUrl!,
                      width: 118,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(),
                    )
                  : _fallback(),
            ),
            const SizedBox(height: 6),
            Text(
              show.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              show.nextLabel,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 4),
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

  Widget _fallback() => Container(
        width: 118,
        height: 150,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.tv_rounded),
      );
}
