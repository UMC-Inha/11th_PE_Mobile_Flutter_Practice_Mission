import 'package:movielog/data/models/favorite_response_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';

/// 내 즐겨찾기 목록의 카드 한 장. 즐겨찾기(MovieLog)와 영화 정보(TMDB)를 movieId로 합친다.
///
/// [movie]가 null이면 그 한 건의 영화 정보만 가져오지 못한 것이다(목록 전체의 실패가 아니다).
class FavoriteListItem {
  const FavoriteListItem({
    required this.favorite,
    this.movie,
    this.errorMessage,
  });

  final FavoriteResponseDto favorite;
  final TmdbMovieDto? movie;
  final String? errorMessage;

  bool get hasMovie => movie != null;

  FavoriteListItem withMovie(TmdbMovieDto movie) =>
      FavoriteListItem(favorite: favorite, movie: movie);

  FavoriteListItem withError(String message) =>
      FavoriteListItem(favorite: favorite, errorMessage: message);
}
