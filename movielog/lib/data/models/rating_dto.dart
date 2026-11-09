/// `GET /v6/members/{memberId}/ratings` 응답 배열의 평점 하나입니다.
/// 영화 제목·포스터는 포함하지 않으므로 movieId로 TMDB 영화와 연결합니다.
class RatingDto {
  const RatingDto({
    required this.ratingId,
    required this.movieId,
    required this.score,
    required this.comment,
    required this.createdAt,
  });

  final int ratingId;
  final int movieId;
  final int score;

  /// 명세에서 nullable이므로 후기가 없을 수 있습니다.
  final String? comment;
  final DateTime createdAt;

  factory RatingDto.fromJson(Map<String, dynamic> json) => RatingDto(
    ratingId: (json['ratingId'] as num).toInt(),
    movieId: (json['movieId'] as num).toInt(),
    score: (json['score'] as num).toInt(),
    comment: json['comment'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
