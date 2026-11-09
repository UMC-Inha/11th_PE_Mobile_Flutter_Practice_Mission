import 'package:dio/dio.dart';

import '../models/check_result.dart';
import '../models/common_response.dart';
import '../models/create_member_request.dart';
import '../models/sign_up_models.dart';

/// 워크북 v6 회원 API를 호출합니다. (구 MemberCheckService)
class SignUpService {
  SignUpService(this._dio);
  final Dio _dio;

  /// 닉네임을 사용할 수 있으면 true를 반환합니다.
  /// 성공 응답은 공통 형식 없이 `{ "available": true }`를 그대로 반환합니다.
  Future<bool> checkNickname(String nickname) async {
    final encoded = Uri.encodeComponent(nickname.trim());
    final response = await _dio.get('/v6/members/nickname/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }

  /// 이메일을 사용할 수 있으면 true를 반환합니다.
  Future<bool> checkEmail(String email) async {
    final encoded = Uri.encodeComponent(email.trim());
    final response = await _dio.get('/v6/members/email/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }

  /// 회원가입 성공(201) 응답은 공통 형식이며 result에 회원 정보가 들어 있습니다.
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    final response = await _dio.post('/v6/members', data: request.toJson());

    return CommonResponse<SignUpResult>.fromJson(
      response.data as Map<String, dynamic>,
      (value) => SignUpResult.fromJson(value as Map<String, dynamic>),
    );
  }
}

/// 회원가입 실패 응답의 서버 message를 그대로 사용합니다.
/// 400(비밀번호 형식)·409(이메일/닉네임 중복) 모두 사용자에게 보여줄 수 있는 문장입니다.
String writeSignUpErrorMessage(DioException error) {
  final common = CommonResponse.tryParseError(error.response?.data);
  return common?.message ?? '회원가입에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}
