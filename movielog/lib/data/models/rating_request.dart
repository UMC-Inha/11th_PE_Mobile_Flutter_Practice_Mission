/// 서버 평점은 1~5 사이 정수입니다. 반 점이나 범위 밖 값을 조용히 바꾸지 않고 막습니다.
int validateServerScore(double value) {
  if (value < 1 || value > 5 || value != value.roundToDouble()) {
    throw ArgumentError('서버 평점은 1~5 사이 정수여야 합니다.');
  }
  return value.toInt();
}

/// `POST /v6/members/{memberId}/ratings` 요청 body입니다.
class CreateRatingRequest {
  const CreateRatingRequest({
    required this.movieId,
    required this.score,
    this.comment,
  });

  /// 5주차 `TmdbMovieDto.id`입니다. 영화 배열의 index가 아닙니다.
  final int movieId;
  final int score;
  final String? comment;

  Map<String, dynamic> toJson() => {
    'movieId': movieId,
    'score': score,
    // 등록 comment는 선택 항목이라 비어 있으면 생략합니다.
    if (comment != null && comment!.trim().isNotEmpty)
      'comment': comment!.trim(),
  };
}

/// `PATCH /v6/members/{memberId}/ratings/{ratingId}` 요청 body입니다.
/// comment를 생략하면 서버가 기존 후기를 null로 덮으므로 항상 함께 보냅니다.
class UpdateRatingRequest {
  const UpdateRatingRequest({required this.score, required this.comment});

  final int score;

  /// null이면 후기를 지우겠다는 뜻입니다.
  final String? comment;

  Map<String, dynamic> toJson() => {'score': score, 'comment': comment};
}
