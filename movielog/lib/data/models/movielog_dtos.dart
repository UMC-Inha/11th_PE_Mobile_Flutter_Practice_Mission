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

/// 서버 score는 1~5 사이 정수다. 별점 위젯이 정수 단위로 막아 주더라도,
/// 반 점이 조용히 `toInt()`로 잘려 나가지 않도록 요청을 만들기 직전에 한 번 더 확인한다.
int validateServerScore(double value) {
  if (value < 1 || value > 5 || value != value.roundToDouble()) {
    throw ArgumentError('서버 평점은 1~5 사이 정수여야 합니다.');
  }
  return value.toInt();
}

/// POST /members/{memberId}/ratings 요청 Body. `movieId`에는 배열 index가 아니라
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

  /// 등록 때 후기는 선택 항목이라 비어 있으면 빈 문자열 대신 아예 생략한다.
  Map<String, dynamic> toJson() => {
    'movieId': movieId,
    'score': score,
    if (comment != null && comment!.trim().isNotEmpty)
      'comment': comment!.trim(),
  };
}

/// PATCH /members/{memberId}/ratings/{ratingId} 요청 Body.
///
/// PATCH지만 score는 필수다. 서버에 따라 comment를 생략하면 기존 후기가 지워지는 계약이라
/// (워크북 v6), 후기를 유지·삭제하려는 의도를 항상 명시한다.
/// 비어 있으면 `null`을 그대로 보내 "후기를 지운다"는 뜻을 분명히 한다.
class UpdateRatingRequest {
  const UpdateRatingRequest({required this.score, this.comment})
    : assert(score >= 1 && score <= 5);

  final int score;
  final String? comment;

  Map<String, dynamic> toJson() {
    final text = comment?.trim() ?? '';
    return {'score': score, 'comment': text.isEmpty ? null : text};
  }
}
