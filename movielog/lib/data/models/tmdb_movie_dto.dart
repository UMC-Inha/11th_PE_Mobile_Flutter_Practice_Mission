/// TMDB 영화 한 편(Popular·Discover의 results 항목, Movie Details 응답).
///
/// JSON은 snake_case(`poster_path`), Dart는 lowerCamelCase(`posterPath`)라서
/// key를 하나씩 명시적으로 연결한다. 값만 담고 화면 동작은 갖지 않는다.
class TmdbMovieDto {
  const TmdbMovieDto({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.releaseDate,
    required this.genreIds,
    required this.voteAverage,
    required this.popularity,
  });

  /// TMDB가 영화마다 부여한 식별자. 자체 백엔드 평점의 `movieId`로 그대로 보낸다.
  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final List<int> genreIds;
  final double voteAverage;
  final double popularity;

  factory TmdbMovieDto.fromJson(Map<String, dynamic> json) {
    // 목록 응답은 genre_ids: [18], 상세 응답은 genres: [{id, name}] 모양이다.
    final rawGenreIds =
        json['genre_ids'] as List<dynamic>? ??
        (json['genres'] as List<dynamic>? ?? const [])
            .map((genre) => (genre as Map<String, dynamic>)['id'])
            .toList();

    return TmdbMovieDto(
      id: (json['id'] as num).toInt(),
      title: _nonEmpty(json['title'] as String?) ?? '제목 없음',
      overview: json['overview'] as String? ?? '',
      posterPath: _nonEmpty(json['poster_path'] as String?),
      backdropPath: _nonEmpty(json['backdrop_path'] as String?),
      releaseDate: _nonEmpty(json['release_date'] as String?),
      genreIds: rawGenreIds.map((value) => (value as num).toInt()).toList(),
      voteAverage: (json['vote_average'] as num? ?? 0).toDouble(),
      popularity: (json['popularity'] as num? ?? 0).toDouble(),
    );
  }
}

/// TMDB는 값이 없을 때 null 대신 빈 문자열("")을 줄 때도 있어 둘 다 null로 맞춘다.
String? _nonEmpty(String? value) =>
    (value == null || value.trim().isEmpty) ? null : value;
