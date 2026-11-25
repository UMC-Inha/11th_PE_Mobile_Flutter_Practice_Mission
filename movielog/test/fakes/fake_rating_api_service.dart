import 'dart:async';

import 'package:dio/dio.dart';

import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/services/rating_api_service.dart';

/// 실제 워크북 서버 대신 메모리 목록으로 평점 CRUD를 흉내 내는 테스트용 Service입니다.
class FakeRatingApiService extends RatingApiService {
  FakeRatingApiService({List<RatingDto> ratings = const []})
    : ratings = [...ratings],
      super(Dio(), Dio());

  final List<RatingDto> ratings;

  /// 설정하면 쓰기 요청이 이 상태 코드·공통 오류 body로 실패합니다.
  int? writeFailStatus;
  String? writeFailCode;
  String writeFailMessage = '요청을 처리하지 못했습니다.';

  /// 설정하면 쓰기 응답을 이 Completer가 끝날 때까지 늦춥니다. (저장 중 상태 재현)
  Completer<void>? writeGate;

  final createRequests = <Map<String, dynamic>>[];
  final updateRequests = <Map<String, dynamic>>[];
  final deleteRequests = <int>[];
  int _nextRatingId = 100;

  @override
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    createRequests.add(request.toJson());
    await _beforeWrite('/v8/ratings');
    final created = RatingDto(
      ratingId: _nextRatingId++,
      movieId: request.movieId,
      score: request.score,
      comment: request.comment,
      createdAt: DateTime.utc(2026, 11, 9),
    );
    ratings.add(created);
    return created;
  }

  @override
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    updateRequests.add({'ratingId': ratingId, 'score': score, 'comment': comment});
    await _beforeWrite('/v8/ratings/$ratingId');
    final index = ratings.indexWhere((r) => r.ratingId == ratingId);
    final old = ratings[index];
    return ratings[index] = RatingDto(
      ratingId: old.ratingId,
      movieId: old.movieId,
      score: score,
      comment: comment,
      createdAt: old.createdAt,
    );
  }

  @override
  Future<void> deleteRating(int ratingId) async {
    deleteRequests.add(ratingId);
    await _beforeWrite('/v8/ratings/$ratingId');
    ratings.removeWhere((r) => r.ratingId == ratingId);
  }

  Future<void> _beforeWrite(String path) async {
    await writeGate?.future;
    final status = writeFailStatus;
    if (status != null) throw _error(path, status);
  }

  DioException _error(String path, int status) {
    final options = RequestOptions(path: path);
    return DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: options,
        statusCode: status,
        data: {
          'isSuccess': false,
          'code': writeFailCode ?? 'COMMON$status',
          'message': writeFailMessage,
          'result': null,
        },
      ),
    );
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
