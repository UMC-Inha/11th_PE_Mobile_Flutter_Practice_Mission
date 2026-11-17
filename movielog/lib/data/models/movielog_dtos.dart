// MovieLog 자체 백엔드(5주차 NestJS movie 프로젝트) 요청·응답 DTO.

/// GET /members/nickname/{nickname}, GET /members/email/{email}
class AvailabilityDto {
  const AvailabilityDto({required this.available});

  final bool available;

  factory AvailabilityDto.fromJson(Map<String, dynamic> json) {
    return AvailabilityDto(available: json['available'] as bool);
  }
}

/// GET /members/{memberId}/ratings 의 한 줄
class MemberRatingDto {
  const MemberRatingDto({
    required this.ratingId,
    required this.movieId,
    required this.score,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  final int ratingId;

  /// TMDB 영화 ID. 이 값으로 TMDB에서 제목·포스터를 찾는다.
  final int movieId;
  final int score;
  final String? comment;
  final DateTime createdAt;
  final DateTime updatedAt;

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

/// 6주차 평점 등록 API의 요청 Body. `movieId`에는 배열 index가 아니라
/// TMDB 응답의 `id`(TmdbMovieDto.id)를 그대로 넣는다.
class CreateRatingRequest {
  const CreateRatingRequest({
    required this.movieId,
    required this.score,
    this.comment,
  }) : assert(score >= 1 && score <= 5);

  final int movieId;
  final int score;
  final String? comment;

  Map<String, dynamic> toJson() => {
    'movieId': movieId,
    'score': score,
    if (comment != null) 'comment': comment,
  };
}
