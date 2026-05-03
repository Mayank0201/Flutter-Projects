import 'dart:async';
import 'package:flutter/material.dart';
import '../../../model/movie_model.dart';
import '../../../service/discovery_service.dart';
import 'movie_details_page.dart';

// Mood definitions matching the backend MoodMatcherService.Mood enum
const _moods = [
  _MoodOption(
    key: 'ENERGETIC',
    label: 'Energetic',
    emoji: '⚡',
    description: 'Action-packed & adrenaline',
    gradient: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
  ),
  _MoodOption(
    key: 'CHILL',
    label: 'Chill',
    emoji: '🌿',
    description: 'Feel-good & relaxing',
    gradient: [Color(0xFF43B89C), Color(0xFF5ECFA0)],
  ),
  _MoodOption(
    key: 'EMOTIONAL',
    label: 'Emotional',
    emoji: '💫',
    description: 'Drama & heartfelt stories',
    gradient: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
  ),
  _MoodOption(
    key: 'SPOOKY',
    label: 'Spooky',
    emoji: '👻',
    description: 'Horror & thrills',
    gradient: [Color(0xFF1F1F2E), Color(0xFF4A3F6B)],
  ),
  _MoodOption(
    key: 'CURIOUS',
    label: 'Curious',
    emoji: '🔭',
    description: 'Sci-fi & documentary',
    gradient: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
  ),
  _MoodOption(
    key: 'FAMILY',
    label: 'Family',
    emoji: '🏡',
    description: 'Magic & adventures',
    gradient: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
  ),
];

class _MoodOption {
  final String key;
  final String label;
  final String emoji;
  final String description;
  final List<Color> gradient;

  const _MoodOption({
    required this.key,
    required this.label,
    required this.emoji,
    required this.description,
    required this.gradient,
  });
}

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  final DiscoveryService _service = DiscoveryService();

  String? _selectedMood;
  List<Movie> _movies = [];
  List<Movie> _trendingMovies = [];
  List<Movie> _recommendations = [];
  bool _isMoodLoading = false;
  bool _isTrendingLoading = true;
  bool _isRecLoading = true;
  String? _moodError;
  String? _trendingError;
  String? _recError;
  bool _isTakingLong = false;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    _startLoadingTimer();
    _loadRecommendations();
    _loadTrending();
  }

  void _startLoadingTimer() {
    _loadingTimer?.cancel();
    _isTakingLong = false;
    _loadingTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && (_isTrendingLoading || _isRecLoading)) {
        setState(() => _isTakingLong = true);
      }
    });
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isRecLoading = true;
      _recError = null;
    });
    try {
      final movies = await _service.getRecommendations();
      if (!mounted) return;
      setState(() {
        _recommendations = movies;
        _isRecLoading = false;
        if (!_isTrendingLoading) _loadingTimer?.cancel();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recError = 'Could not load recommendations.';
        _isRecLoading = false;
      });
    }
  }

  Future<void> _loadTrending() async {
    setState(() {
      _isTrendingLoading = true;
      _trendingError = null;
    });
    try {
      final movies = await _service.getTrending();
      if (!mounted) return;
      setState(() {
        _trendingMovies = movies;
        _isTrendingLoading = false;
        if (!_isRecLoading) _loadingTimer?.cancel();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _trendingError = 'Could not load trending movies.';
        _isTrendingLoading = false;
      });
    }
  }

  Future<void> _loadMood(String mood) async {
    setState(() {
      _selectedMood = mood;
      _isMoodLoading = true;
      _moodError = null;
      _movies = [];
    });
    try {
      final movies = await _service.getMoodMatch(mood);
      if (!mounted) return;
      setState(() {
        _movies = movies;
        _isMoodLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _moodError = 'Could not load movies for this mood.';
        _isMoodLoading = false;
      });
    }
  }

  void _openMovie(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MovieDetailsPage(movie: movie)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_rounded, color: colorScheme.primary, size: 22),
            const SizedBox(width: 8),
            const Text('Discover'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mood section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "What's your mood?",
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pick a vibe and we\'ll find the perfect movie',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),

            // Mood grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              crossAxisCount: 3,
              childAspectRatio: 1.1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: _moods
                  .map((m) => _MoodCard(
                        mood: m,
                        isSelected: _selectedMood == m.key,
                        onTap: () => _loadMood(m.key),
                      ))
                  .toList(),
            ),

            const SizedBox(height: 20),

            // Mood results
            if (_selectedMood != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Text(
                      '${_moods.firstWhere((m) => m.key == _selectedMood).emoji}  ${_moods.firstWhere((m) => m.key == _selectedMood).label} Picks',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (_isMoodLoading) ...[
                      const SizedBox(width: 12),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ),
              if (_moodError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(_moodError!,
                      style: TextStyle(color: colorScheme.error)),
                )
              else if (!_isMoodLoading && _movies.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'No movies found for this mood.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                )
              else if (_movies.isNotEmpty)
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _movies.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) =>
                        _MovieCard(movie: _movies[i], onTap: _openMovie),
                  ),
                ),
              const SizedBox(height: 24),
            ],

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(
                  color: colorScheme.outline.withValues(alpha: 0.2)),
            ),
            const SizedBox(height: 16),
            
            // Recommendations section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Text(
                    '✨  Recommended For You',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (_isRecLoading) ...[
                    const SizedBox(width: 12),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),

            if (_recError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(_recError!,
                    style: TextStyle(color: colorScheme.error)),
              )
            else if (!_isRecLoading)
              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _recommendations.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _MovieCard(
                      movie: _recommendations[i], onTap: _openMovie),
                ),
              ),

            const SizedBox(height: 16),

            // Trending section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Text(
                    '🔥  Trending Now',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (_isTrendingLoading) ...[
                    const SizedBox(width: 12),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),

            if (_trendingError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(_trendingError!,
                    style: TextStyle(color: colorScheme.error)),
              )
            else if (!_isTrendingLoading)
              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _trendingMovies.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _MovieCard(
                      movie: _trendingMovies[i], onTap: _openMovie),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: (_isTrendingLoading || _isRecLoading) && _isTakingLong
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              color: colorScheme.surfaceContainerHigh,
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Taking longer than usual, please wait...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _loadRecommendations();
                      _loadTrending();
                      _startLoadingTimer();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

// ── Mood card ──────────────────────────────────────────────────────────────

class _MoodCard extends StatelessWidget {
  final _MoodOption mood;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoodCard({
    required this.mood,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: mood.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: mood.gradient.first.withValues(alpha: 0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(mood.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              mood.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Horizontal movie card ──────────────────────────────────────────────────

class _MovieCard extends StatelessWidget {
  final Movie movie;
  final void Function(Movie) onTap;

  const _MovieCard({required this.movie, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => onTap(movie),
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: movie.poster.isNotEmpty
                      ? Image.network(
                          movie.poster,
                          width: 130,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _placeholder(colorScheme),
                        )
                      : _placeholder(colorScheme),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              movie.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) => Container(
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.movie_rounded,
            color: cs.onSurfaceVariant, size: 36),
      );
}
