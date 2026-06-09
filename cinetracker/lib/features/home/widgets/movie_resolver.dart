import 'package:flutter/material.dart';
import '../../../model/movie_model.dart';
import '../../../service/tmdb_service.dart';

class MovieResolver extends StatefulWidget {
  final int movieId;
  final String? initialTitle;
  final String? initialPosterUrl;
  final int? initialReleaseYear;
  final String? initialGenre;
  final Widget Function(
    BuildContext context,
    String title,
    String? posterUrl,
    int? releaseYear,
    String? genre,
    bool isLoading,
  ) builder;

  const MovieResolver({
    super.key,
    required this.movieId,
    this.initialTitle,
    this.initialPosterUrl,
    this.initialReleaseYear,
    this.initialGenre,
    required this.builder,
  });

  @override
  State<MovieResolver> createState() => _MovieResolverState();
}

class _MovieResolverState extends State<MovieResolver> {
  static final Map<int, Movie> _movieCache = {};

  String? _resolvedTitle;
  String? _resolvedPosterUrl;
  int? _resolvedReleaseYear;
  String? _resolvedGenre;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resolveMetadata();
  }

  @override
  void didUpdateWidget(MovieResolver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movieId != widget.movieId) {
      _resolveMetadata();
    }
  }

  void _resolveMetadata() {
    final titleEmpty = widget.initialTitle == null ||
        widget.initialTitle!.isEmpty ||
        widget.initialTitle == 'Unknown' ||
        widget.initialTitle == 'Unknown Movie';
    final posterEmpty = widget.initialPosterUrl == null ||
        widget.initialPosterUrl!.isEmpty;

    if (!titleEmpty && !posterEmpty) {
      _resolvedTitle = widget.initialTitle;
      _resolvedPosterUrl = widget.initialPosterUrl;
      _resolvedReleaseYear = widget.initialReleaseYear;
      _resolvedGenre = widget.initialGenre;
      _isLoading = false;
      return;
    }

    // Check static cache first
    if (_movieCache.containsKey(widget.movieId)) {
      final cached = _movieCache[widget.movieId]!;
      _resolvedTitle = cached.title;
      _resolvedPosterUrl = cached.poster;
      _resolvedReleaseYear = cached.releaseYear;
      _resolvedGenre = cached.genre;
      _isLoading = false;
      return;
    }

    // Fetch from TMDB
    _resolvedTitle = widget.initialTitle ?? 'Loading...';
    _resolvedPosterUrl = widget.initialPosterUrl;
    _resolvedReleaseYear = widget.initialReleaseYear;
    _resolvedGenre = widget.initialGenre;
    _isLoading = true;

    _fetchMovieFromTmdb();
  }

  Future<void> _fetchMovieFromTmdb() async {
    try {
      final movie = await TMDBService().getMovieDetails(widget.movieId);
      _movieCache[widget.movieId] = movie;
      if (mounted) {
        setState(() {
          _resolvedTitle = movie.title;
          _resolvedPosterUrl = movie.poster;
          _resolvedReleaseYear = movie.releaseYear;
          _resolvedGenre = movie.genre;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error resolving movie ${widget.movieId}: $e');
      if (mounted) {
        setState(() {
          _resolvedTitle = widget.initialTitle ?? 'Unknown Movie';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      _resolvedTitle ?? 'Unknown Movie',
      _resolvedPosterUrl,
      _resolvedReleaseYear,
      _resolvedGenre,
      _isLoading,
    );
  }
}
