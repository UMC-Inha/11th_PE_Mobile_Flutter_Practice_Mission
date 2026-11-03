import 'dart:async';

import 'package:dio/dio.dart';

import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/services/rating_api_service.dart';

/// 실제 워크북 서버 대신 미리 정해 둔 평점을 돌려주는 테스트용 Service입니다.
class FakeRatingApiService extends RatingApiService {
  FakeRatingApiService({this.ratings = const [], this.failStatusCode})
      : super(Dio());

  final List<RatingDto> ratings;

  /// 설정하면 해당 상태 코드의 DioException을 던집니다.
  final int? failStatusCode;

  /// 설정하면 응답을 이 Completer가 끝날 때까지 늦춥니다. (Loading 상태 재현)
  Completer<void>? gate;

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    await gate?.future;
    final status = failStatusCode;
    if (status != null) {
      final options = RequestOptions(path: '/v5/members/$memberId/ratings');
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: options, statusCode: status),
      );
    }
    return ratings;
  }
}

RatingDto sampleRating({
  int ratingId = 1,
  int movieId = 550,
  int score = 5,
  String? comment = '최고의 영화!',
}) {
  return RatingDto(
    ratingId: ratingId,
    movieId: movieId,
    score: score,
    comment: comment,
    createdAt: DateTime.utc(2026, 9, 6, 12),
  );
}
