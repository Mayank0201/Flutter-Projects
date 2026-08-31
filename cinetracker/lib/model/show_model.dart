// tv show models. mirrors the backend ShowSummaryResponse and ShowProgressResponse.

// a show as it shows up in a grid or search result
class Show {
  final int tmdbId;
  final String title;
  final String? posterUrl;
  final String overview;
  final double tmdbRating;
  final int? firstAirYear;
  final String genre;

  Show({
    required this.tmdbId,
    required this.title,
    this.posterUrl,
    this.overview = "",
    this.tmdbRating = 0.0,
    this.firstAirYear,
    this.genre = "N/A",
  });

  factory Show.fromJson(Map<String, dynamic> json) {
    // backend sends posterUrl already built, but fall back to posterPath just in case
    String? poster = json["posterUrl"] as String?;
    if (poster == null) {
      final path = json["posterPath"] as String?;
      if (path != null && path.isNotEmpty) {
        poster = "https://image.tmdb.org/t/p/w500$path";
      }
    }

    return Show(
      tmdbId: (json["tmdbId"] ?? json["id"] ?? 0) as int,
      title: (json["title"] ?? json["name"] ?? "Unknown") as String,
      posterUrl: poster,
      overview: (json["overview"] ?? "") as String,
      tmdbRating: ((json["tmdbRating"] ?? json["voteAverage"] ?? 0) as num).toDouble(),
      firstAirYear: json["firstAirYear"] as int?,
      genre: (json["genre"] ?? "N/A") as String,
    );
  }
}

// one season and how far the user is through it
class SeasonProgress {
  final int seasonId;
  final int seasonNumber;
  final String? name;
  final String? posterPath;
  final String? airDate;
  final int episodeCount;
  final int watchedCount;
  final int percentComplete;
  final bool complete;
  // episode numbers the user has watched, so we can tick the boxes
  final Set<int> watchedEpisodes;

  SeasonProgress({
    required this.seasonId,
    required this.seasonNumber,
    this.name,
    this.posterPath,
    this.airDate,
    required this.episodeCount,
    required this.watchedCount,
    required this.percentComplete,
    required this.complete,
    required this.watchedEpisodes,
  });

  String get displayName =>
      (name != null && name!.isNotEmpty) ? name! : "Season $seasonNumber";

  factory SeasonProgress.fromJson(Map<String, dynamic> json) {
    final watched = (json["watchedEpisodes"] as List?) ?? const [];
    return SeasonProgress(
      seasonId: (json["seasonId"] ?? 0) as int,
      seasonNumber: (json["seasonNumber"] ?? 0) as int,
      name: json["name"] as String?,
      posterPath: json["posterPath"] as String?,
      airDate: json["airDate"] as String?,
      episodeCount: (json["episodeCount"] ?? 0) as int,
      watchedCount: (json["watchedCount"] ?? 0) as int,
      percentComplete: (json["percentComplete"] ?? 0) as int,
      complete: (json["complete"] ?? false) as bool,
      watchedEpisodes: watched.map((e) => e as int).toSet(),
    );
  }
}

// a show, how far the user is, and what to watch next
class ShowProgress {
  final int showId;
  final int tmdbId;
  final String title;
  final String? posterPath;
  final String overview;
  final String? genre;
  final String? tmdbStatus;
  final String? status;
  final int episodesWatched;
  final int totalEpisodes;
  final int percentComplete;
  final int minutesWatched;
  final int? nextSeasonNumber;
  final int? nextEpisodeNumber;
  final List<SeasonProgress> seasons;

  ShowProgress({
    required this.showId,
    required this.tmdbId,
    required this.title,
    this.posterPath,
    this.overview = "",
    this.genre,
    this.tmdbStatus,
    this.status,
    required this.episodesWatched,
    required this.totalEpisodes,
    required this.percentComplete,
    required this.minutesWatched,
    this.nextSeasonNumber,
    this.nextEpisodeNumber,
    this.seasons = const [],
  });

  String? get posterUrl => (posterPath != null && posterPath!.isNotEmpty)
      ? "https://image.tmdb.org/t/p/w500$posterPath"
      : null;

  bool get hasNext => nextSeasonNumber != null && nextEpisodeNumber != null;

  // "S2 E5", for the continue watching card
  String get nextLabel =>
      hasNext ? "S$nextSeasonNumber E$nextEpisodeNumber" : "All caught up";

  factory ShowProgress.fromJson(Map<String, dynamic> json) {
    final seasons = (json["seasons"] as List?) ?? const [];
    return ShowProgress(
      showId: (json["showId"] ?? 0) as int,
      tmdbId: (json["tmdbId"] ?? 0) as int,
      title: (json["title"] ?? "Unknown") as String,
      posterPath: json["posterPath"] as String?,
      overview: (json["overview"] ?? "") as String,
      genre: json["genre"] as String?,
      tmdbStatus: json["tmdbStatus"] as String?,
      status: json["status"] as String?,
      episodesWatched: (json["episodesWatched"] ?? 0) as int,
      totalEpisodes: (json["totalEpisodes"] ?? 0) as int,
      percentComplete: (json["percentComplete"] ?? 0) as int,
      minutesWatched: (json["minutesWatched"] ?? 0) as int,
      nextSeasonNumber: json["nextSeasonNumber"] as int?,
      nextEpisodeNumber: json["nextEpisodeNumber"] as int?,
      seasons: seasons
          .map((e) => SeasonProgress.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// one episode, from tmdb through the backend
class Episode {
  final int episodeNumber;
  final String name;
  final String overview;
  final String? stillPath;
  final String? airDate;
  final int? runtime;

  Episode({
    required this.episodeNumber,
    required this.name,
    this.overview = "",
    this.stillPath,
    this.airDate,
    this.runtime,
  });

  String? get stillUrl => (stillPath != null && stillPath!.isNotEmpty)
      ? "https://image.tmdb.org/t/p/w300$stillPath"
      : null;

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      episodeNumber: (json["episode_number"] ?? 0) as int,
      name: (json["name"] ?? "Episode") as String,
      overview: (json["overview"] ?? "") as String,
      stillPath: json["still_path"] as String?,
      airDate: json["air_date"] as String?,
      runtime: json["runtime"] as int?,
    );
  }
}
