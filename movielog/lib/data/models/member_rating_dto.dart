/// 서버 `GET /members/{memberId}/ratings` 응답의 평점 하나를 표현하는 DTO입니다.
class MemberRatingDto {
  const MemberRatingDto({
    required this.ratingId,
    required this.movieId,
    required this.score,
    this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  final int ratingId;
  final int movieId;
  final int score;
  final String? comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 서버의 LocalDateTime은 "2026-10-28T12:34:56" 같은 ISO 문자열로 내려옵니다.
  factory MemberRatingDto.fromJson(Map<String, dynamic> json) {
    return MemberRatingDto(
      ratingId: (json['ratingId'] as num).toInt(),
      movieId: (json['movieId'] as num).toInt(),
      score: (json['score'] as num).toInt(),
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
