import 'package:dio/dio.dart';

/// 서버 실패 응답 `{ isSuccess, code, message, result }`에서 code를 꺼낸다.
/// 응답이 이 틀이 아니거나(프록시 오류 페이지 등) 없으면 null이다.
String? apiErrorCode(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final code = data['code'];
  return code is String ? code : null;
}

/// 서버 실패 응답의 message. 사용자에게 보여줄 문장이 이미 들어 있다.
String? apiErrorMessage(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final message = data['message'];
  return message is String ? message : null;
}

/// 보호 요청에서 "토큰이 없다·무효다·만료됐다"는 뜻의 code(AUTH401_2/3/4).
/// 로그인 입력 오류인 AUTH401_1은 여기에 속하지 않는다.
bool isSessionExpiredCode(String? code) =>
    code == 'AUTH401_2' || code == 'AUTH401_3' || code == 'AUTH401_4';
