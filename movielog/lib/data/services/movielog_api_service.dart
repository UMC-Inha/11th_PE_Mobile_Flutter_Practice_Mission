import 'package:dio/dio.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/movielog_dtos.dart';
import 'package:movielog/data/models/sign_up_models.dart';

/// MovieLog 자체 백엔드의 **공개** API Service(닉네임·이메일 중복 확인, 회원가입, 유저별 평점 조회).
/// 토큰이 필요 없는 요청만 있어 공개 Client로 보낸다. TMDB Service와 Client를 공유하지 않는다.
///
/// 로그인은 [AuthApiService], 내 정보는 [MemberApiService], 평점 등록·수정·삭제는
/// [RatingApiService]가 맡는다(셋 다 8주차 추가, 뒤의 둘은 보호 Client).
///
/// 성공 응답의 모양이 API마다 다르다. 호출마다 그 계약에 맞춰 파싱한다.
/// - 중복 확인·평점 조회: 예전 그대로 직접 객체/배열
/// - 회원가입: 201 + 공통 응답 틀
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
