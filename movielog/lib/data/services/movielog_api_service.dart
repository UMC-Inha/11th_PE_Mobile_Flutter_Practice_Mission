import 'package:dio/dio.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/movielog_dtos.dart';
import 'package:movielog/data/models/sign_up_models.dart';

/// MovieLog 자체 백엔드(회원·평점) Service. TMDB Service와 Client를 공유하지 않는다.
///
/// 성공 응답의 모양이 API마다 다르다. 호출마다 그 계약에 맞춰 파싱한다.
/// - 중복 확인·평점 조회: 예전 그대로 직접 객체/배열
/// - 회원가입·평점 등록: 201 + 공통 응답 틀
/// - 평점 수정: 200 (result는 쓰지 않는다)
/// - 평점 삭제: 204, 본문이 없으므로 JSON으로 파싱하지 않는다
class MovieLogApiService {
  MovieLogApiService(this._dio);

  final Dio _dio;

  Future<AvailabilityDto> checkNickname(String nickname) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/members/nickname/${Uri.encodeComponent(nickname)}',
    );
    return AvailabilityDto.fromJson(response.data!);
  }

  Future<AvailabilityDto> checkEmail(String email) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/members/email/${Uri.encodeComponent(email)}',
    );
    return AvailabilityDto.fromJson(response.data!);
  }

  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/members',
      data: request.toJson(),
    );
    return CommonResponse<SignUpResult>.fromJson(
      response.data!,
      (value) => SignUpResult.fromJson(value as Map<String, dynamic>),
    );
  }

  Future<List<MemberRatingDto>> fetchMemberRatings(int memberId) async {
    final response = await _dio.get<List<dynamic>>(
      '/members/$memberId/ratings',
    );
    return (response.data ?? const [])
        .map((item) => MemberRatingDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    final response = await _dio.post<Object?>(
      '/members/$memberId/ratings',
      data: request.toJson(),
    );
    // 201을 성공으로 처리한다. 등록 응답의 result 모양(숫자/객체/null)은 서버마다 달라
    // 파싱하지 않고, 성공 뒤에는 GET으로 목록을 다시 확인한다.
    if (response.statusCode != 201) {
      throw StateError('예상하지 못한 등록 응답: ${response.statusCode}');
    }
  }

  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required UpdateRatingRequest request,
  }) async {
    await _dio.patch<Object?>(
      '/members/$memberId/ratings/$ratingId',
      data: request.toJson(),
    );
  }

  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    final response = await _dio.delete<Object?>(
      '/members/$memberId/ratings/$ratingId',
    );
    // 204는 body가 없다. response.data를 Map으로 캐스팅하지 않는다.
    if (response.statusCode != 204) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

/// 실패 응답 body가 공통 응답 틀이면 그대로 읽고, 아니면 null.
/// 서버가 틀을 지키지 않는 응답(프록시 오류 페이지 등)에서도 화면이 멈추지 않게 한다.
CommonResponse<Object?>? parseErrorResponse(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  try {
    return CommonResponse<Object?>.fromJson(data, (value) => value);
  } catch (_) {
    return null;
  }
}

/// 403·404는 화면에 남은 목록이 서버 상태와 어긋났다는 뜻이라 다시 조회해 맞춘다.
/// 400(별점 범위)·409(중복 등록)는 같은 화면에서 값만 고치면 되므로 다시 조회하지 않는다.
///
/// 서버가 내려 주는 code 문자열은 주차마다 다듬어지므로(COMMON403 → RATING403_1 …)
/// code가 아니라 HTTP 상태로 판단한다.
bool shouldRefreshAfterRatingError(DioException error) {
  final status = error.response?.statusCode;
  return status == 403 || status == 404;
}
