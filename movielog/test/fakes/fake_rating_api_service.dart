import 'dart:async';

import 'package:dio/dio.dart';

import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/services/rating_api_service.dart';

/// 실제 워크북 서버 대신 메모리 목록으로 평점 CRUD를 흉내 내는 테스트용 Service입니다.
class FakeRatingApiService extends RatingApiService {
  FakeRatingApiService({List<RatingDto> ratings = const [], this.failStatusCode})
    : ratings = [...ratings],
      super(Dio());

  final List<RatingDto> ratings;

  /// 설정하면 조회(GET)가 해당 상태 코드의 DioException을 던집니다.
  int? failStatusCode;

  /// 설정하면 쓰기 요청이 이 상태 코드·공통 오류 body로 실패합니다.
  int? writeFailStatus;
  String writeFailMessage = '요청을 처리하지 못했습니다.';

  /// true면 쓰기는 성공하고, 그 다음 조회(GET)만 실패합니다.
  bool failNextFetchAfterWrite = false;

  /// 설정하면 응답을 이 Completer가 끝날 때까지 늦춥니다. (Loading 상태 재현)
  Completer<void>? gate;

  /// 설정하면 쓰기 응답을 이 Completer가 끝날 때까지 늦춥니다. (저장 중 상태 재현)
  Completer<void>? writeGate;

  final createRequests = <Map<String, dynamic>>[];
  final updateRequests = <Map<String, dynamic>>[];
  final deleteRequests = <int>[];
  int fetchCount = 0;
  int _nextRatingId = 100;

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    fetchCount++;
    await gate?.future;
    final status = failStatusCode;
    if (status != null) {
      throw _error('/v6/members/$memberId/ratings', status, withBody: false);
    }
    return [...ratings];
  }

  @override
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    createRequests.add({'memberId': memberId, ...request.toJson()});
    await _beforeWrite('/v6/members/$memberId/ratings');
    ratings.add(
      RatingDto(
        ratingId: _nextRatingId++,
        movieId: request.movieId,
        score: request.score,
        comment: request.comment,
        createdAt: DateTime.utc(2026, 11, 9),
      ),
    );
  }

  @override
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required UpdateRatingRequest request,
  }) async {
    updateRequests.add({'ratingId': ratingId, ...request.toJson()});
    await _beforeWrite('/v6/members/$memberId/ratings/$ratingId');
    final index = ratings.indexWhere((r) => r.ratingId == ratingId);
    final old = ratings[index];
    ratings[index] = RatingDto(
      ratingId: old.ratingId,
      movieId: old.movieId,
      score: request.score,
      comment: request.comment,
      createdAt: old.createdAt,
    );
  }

  @override
  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    deleteRequests.add(ratingId);
    await _beforeWrite('/v6/members/$memberId/ratings/$ratingId');
    ratings.removeWhere((r) => r.ratingId == ratingId);
  }

  Future<void> _beforeWrite(String path) async {
    await writeGate?.future;
    final status = writeFailStatus;
    if (status != null) throw _error(path, status, withBody: true);
    if (failNextFetchAfterWrite) failStatusCode = 500;
  }

  DioException _error(String path, int status, {required bool withBody}) {
    final options = RequestOptions(path: path);
    return DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: options,
        statusCode: status,
        data: withBody
            ? {
                'isSuccess': false,
                'code': 'COMMON$status',
                'message': writeFailMessage,
                'result': null,
              }
            : null,
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
