import 'package:dio/dio.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/movielog_dtos.dart';

/// 평점 등록·수정·삭제. **보호 Client**로만 보낸다. 요청 어디에도 memberId가 없다.
/// 누구의 평점인지는 `Authorization` 헤더의 토큰을 보고 서버가 알아낸다.
///
/// 성공 응답은 호출마다 모양이 다르다.
/// - 등록: 201 + 공통 응답 틀, `result`는 평점 객체
/// - 수정: 200 + 공통 응답 틀, `result`는 수정된 평점 객체
/// - 삭제: 200 + 공통 응답 틀, `result`는 null (6주차의 204가 아니다)
class RatingApiService {
  RatingApiService(this._authDio);

  final Dio _authDio;

  Future<MemberRatingDto> createRating(CreateRatingRequest request) async {
    final response = await _authDio.post<Object?>(
      '/ratings',
      data: request.toJson(),
    );
    if (response.statusCode != 201) {
      throw StateError('예상하지 못한 등록 응답: ${response.statusCode}');
    }
    return parseRatingResult(response.data);
  }

  /// PATCH는 score와 comment를 항상 함께 보낸다. comment를 생략하면 서버에 따라 기존 후기가
  /// 지워질 수 있어서, 유지·삭제 의도를 [UpdateRatingRequest]가 명시한다.
  Future<MemberRatingDto> updateRating({
    required int ratingId,
    required UpdateRatingRequest request,
  }) async {
    final response = await _authDio.patch<Object?>(
      '/ratings/$ratingId',
      data: request.toJson(),
    );
    return parseRatingResult(response.data);
  }

  Future<void> deleteRating(int ratingId) async {
    final response = await _authDio.delete<Object?>('/ratings/$ratingId');
    if (response.statusCode != 200) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

/// 공통 응답 틀의 `result`를 평점 객체로 바꾼다. 틀이 어긋나면 [StateError].
MemberRatingDto parseRatingResult(Object? data) {
  if (data is! Map<String, dynamic>) {
    throw StateError('평점 응답 형식이 올바르지 않습니다.');
  }
  final common = CommonResponse<MemberRatingDto>.fromJson(
    data,
    (value) => MemberRatingDto.fromJson(value as Map<String, dynamic>),
  );
  final rating = common.result;
  if (rating == null) throw StateError('평점 result가 없습니다.');
  return rating;
}
