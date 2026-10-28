import '../data/models/tmdb_movie_dto.dart';

/// 화면에 표시하기 위해 TMDB 영화 값을 가공하는 확장입니다. DTO 자체는 값만 담습니다.
extension TmdbMovieFormat on TmdbMovieDto {
  /// `release_date`(yyyy-MM-dd)의 연도입니다. 없거나 형식이 맞지 않으면 null입니다.
  String? get releaseYear {
    final date = releaseDate;
    if (date == null || date.length < 4) return null;
    return date.substring(0, 4);
  }

  /// TMDB의 10점 만점 평점을 MovieLog의 5점 만점으로 바꾼 값입니다.
  double get fivePointRating => voteAverage / 2;
}
