import 'package:dio/dio.dart';

import '../models/common_response.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';

// lib/data/services/rating_api_service.dart — W6 RatingDto/W7 CommonResponse를 재사용합니다.
RatingDto parseRatingResult(Object? data) {
  if (data is! Map<String, dynamic>) {
    throw StateError('평점 응답 형식이 올바르지 않습니다.');
  }
  final common = CommonResponse<RatingDto>.fromJson(
    data,
    (value) => RatingDto.fromJson(value as Map<String, dynamic>),
  );
  final rating = common.result;
  if (rating == null) throw StateError('평점 result가 없습니다.');
  return rating;
}

List<RatingDto> parseRatingList(Object? data) {
  if (data is! List) throw StateError('평점 목록 응답은 배열이어야 합니다.');
  return data
      .map((value) => RatingDto.fromJson(value as Map<String, dynamic>))
      .toList();
}

class RatingApiService {
  RatingApiService(this._publicDio, this._authDio);
  final Dio _publicDio;
  final Dio _authDio;

  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _publicDio.get('/v8/members/$memberId/ratings');
    return parseRatingList(response.data); // 공개 조회: 직접 배열, 토큰 없음
  }

  Future<RatingDto> createRating(CreateRatingRequest request) async {
    final response = await _authDio.post('/v8/ratings', data: request.toJson());
    return parseRatingResult(response.data);
  }

  // PATCH는 부분 수정이 아니라 전체 교체입니다.
  // comment를 생략하면 서버에 null로 전달되어 기존 후기가 지워집니다.
  // Dialog를 열 때 기존 score·comment를 채워서 항상 두 값을 함께 보내야 합니다.
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final response = await _authDio.patch(
      '/v8/ratings/$ratingId',
      data: {'score': score, 'comment': comment},
    );
    return parseRatingResult(response.data);
  }

  Future<void> deleteRating(int ratingId) async {
    final response = await _authDio.delete('/v8/ratings/$ratingId');
    if (response.statusCode != 200) {
      throw StateError('예상하지 못한 삭제 응답');
    }
  }
}

/// 평점 조회 실패 안내 문구입니다. 서버 message가 있으면 그대로 쓰고, 없으면 상태 코드로 정합니다.
String writeMyRatingsErrorMessage(DioException error) {
  final common = CommonResponse.tryParseError(error.response?.data);
  if (common != null) return common.message;
  final status = error.response?.statusCode;
  if (status == 400) return 'memberId 형식을 다시 확인해 주세요.';
  if (status == 404) return '존재하지 않는 회원입니다.';
  return '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
}

/// 평점 쓰기 실패 안내 문구입니다. 서버 message를 그대로 씁니다.
String writeErrorMessage(DioException error) {
  final common = CommonResponse.tryParseError(error.response?.data);
  return common?.message ?? '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}

/// `MEMBER404_1`·`RATING404_1`은 안내 문구를 보여주고 목록을 새로고침합니다.
bool shouldRefreshAfterRatingError(DioException error) {
  final code = CommonResponse.tryParseError(error.response?.data)?.code;
  if (code != null) return code == 'MEMBER404_1' || code == 'RATING404_1';
  return error.response?.statusCode == 404;
}

/// 평점 쓰기(등록·수정·삭제) 실패를 화면에 전달하는 예외입니다.
/// Dialog는 이 예외의 [message]를 그대로 보여주고 입력을 유지합니다.
class RatingWriteException implements Exception {
  const RatingWriteException(this.message);
  final String message;

  @override
  String toString() => message;
}
