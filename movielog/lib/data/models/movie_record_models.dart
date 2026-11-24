import 'package:movielog/data/models/favorite_response_dto.dart';
import 'package:movielog/data/models/movielog_dtos.dart';

/// `POST /movie-records` 요청 Body. 평점과 즐겨찾기를 한 번에 저장한다.
///
/// - `movieId`는 배열 index가 아니라 TMDB id, memberId는 없다(누구인지는 토큰이 알려 준다).
/// - `comment`는 선택이라 비어 있으면 생략한다.
/// - `addToFavorites`는 **필수 bool**이다. 체크하지 않았어도 `false`를 명시해서 보낸다.
class CreateMovieRecordRequest {
  const CreateMovieRecordRequest({
    required this.movieId,
    required this.score,
    required this.addToFavorites,
    this.comment,
  }) : assert(score >= 1 && score <= 5);

  final int movieId;
  final int score;
  final String? comment;
  final bool addToFavorites;

  Map<String, dynamic> toJson() => {
    'movieId': movieId,
    'score': score,
    if (comment != null && comment!.trim().isNotEmpty)
      'comment': comment!.trim(),
    'addToFavorites': addToFavorites,
  };
}

/// `POST /movie-records` 성공(201)의 `result`. 평점은 항상 있고, 즐겨찾기는
/// `addToFavorites`가 true였을 때만 있다(false였으면 null).
class MovieRecordResponseDto {
  const MovieRecordResponseDto({required this.rating, this.favorite});

  factory MovieRecordResponseDto.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('MovieRecordResponseDto must be a JSON object.');
    }
    final rating = json['rating'];
    if (rating is! Map<String, dynamic>) {
      throw const FormatException('rating must be a JSON object.');
    }
    final favorite = json['favorite'];
    return MovieRecordResponseDto(
      rating: MemberRatingDto.fromJson(rating),
      favorite: favorite == null ? null : FavoriteResponseDto.fromJson(favorite),
    );
  }

  /// 기존 평점 DTO를 그대로 재사용한다.
  final MemberRatingDto rating;

  /// 기존 즐겨찾기 DTO를 그대로 재사용한다.
  final FavoriteResponseDto? favorite;
}
