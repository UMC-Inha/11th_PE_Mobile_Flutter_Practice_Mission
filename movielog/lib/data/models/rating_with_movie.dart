import 'rating_dto.dart';
import 'tmdb_movie_dto.dart';

/// 자체 백엔드의 평점 하나와 그 movieId로 찾은 TMDB 영화를 한 쌍으로 묶습니다.
class RatingWithMovie {
  const RatingWithMovie({
    required this.rating,
    this.movie,
  });

  final RatingDto rating;

  /// TMDB에서 찾지 못했으면 null입니다. 이 경우에도 평점은 화면에 남깁니다.
  final TmdbMovieDto? movie;
}
