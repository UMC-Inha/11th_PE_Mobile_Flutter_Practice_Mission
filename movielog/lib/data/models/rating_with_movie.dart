import 'package:movielog/data/models/movielog_dtos.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';

/// 자체 백엔드의 평점 한 줄 + 그 `movieId`로 찾은 TMDB 영화 한 편.
///
/// 평점(점수·후기·등록일)의 주인은 자체 백엔드이고, 제목·포스터는 TMDB에서 빌려 온다.
class RatingWithMovie {
  const RatingWithMovie({required this.rating, this.movie});

  final MemberRatingDto rating;

  /// TMDB에서 찾지 못했거나 불러오지 못했으면 null. 화면은 제목·포스터를 placeholder로 그리고
  /// `rating.movieId`는 그대로 보여준다.
  final TmdbMovieDto? movie;
}
