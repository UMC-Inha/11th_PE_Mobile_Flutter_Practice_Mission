import 'package:dio/dio.dart';

import '../models/common_response.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';

/// 워크북 v6 회원별 평점 조회·등록·수정·삭제 API를 호출합니다.
class RatingApiService {
  RatingApiService(this._dio);
  final Dio _dio;

  /// 성공 응답은 공통 형식 없이 배열을 그대로 반환합니다.
  /// 평점이 없으면 빈 리스트를 반환합니다. 빈 배열은 실패가 아닙니다.
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _dio.get('/v6/members/$memberId/ratings');
    final list = response.data as List<dynamic>;
    return list
        .map((item) => RatingDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 201을 성공으로 처리합니다.
  /// Swagger 설명(result = ratingId)과 예시(result = null)가 달라 result는 파싱하지 않습니다.
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    final response = await _dio.post(
      '/v6/members/$memberId/ratings',
      data: request.toJson(),
    );
    if (response.statusCode != 201) {
      throw StateError('예상하지 못한 등록 응답: ${response.statusCode}');
    }
  }

  /// 성공은 200 + result null입니다.
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required UpdateRatingRequest request,
  }) async {
    await _dio.patch(
      '/v6/members/$memberId/ratings/$ratingId',
      data: request.toJson(),
    );
  }

  /// 성공은 204이고 body가 없으므로 JSON으로 파싱하지 않습니다.
  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    final response = await _dio.delete(
      '/v6/members/$memberId/ratings/$ratingId',
    );
    if (response.statusCode != 204) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
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

/// 평점 쓰기 실패 안내 문구입니다.
/// 같은 COMMON404라도 등록은 "유저", 수정·삭제는 "평점"을 가리키므로 서버 message를 그대로 씁니다.
String writeErrorMessage(DioException error) {
  final common = CommonResponse.tryParseError(error.response?.data);
  return common?.message ?? '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}

/// 403·404는 화면에 남은 목록이 서버 상태와 어긋났다는 뜻이므로 다시 조회해서 맞춥니다.
/// 400(별점 범위)·409(중복 등록)는 값만 고치거나 다시 시도하면 되므로 재조회하지 않습니다.
bool shouldRefreshAfterRatingError(DioException error) {
  final code = CommonResponse.tryParseError(error.response?.data)?.code;
  if (code != null) return code == 'COMMON403' || code == 'COMMON404';
  final status = error.response?.statusCode;
  return status == 403 || status == 404;
}

/// 평점 쓰기(등록·수정·삭제) 실패를 화면에 전달하는 예외입니다.
/// Dialog는 이 예외의 [message]를 그대로 보여주고 입력을 유지합니다.
class RatingWriteException implements Exception {
  const RatingWriteException(this.message);
  final String message;

  @override
  String toString() => message;
}
