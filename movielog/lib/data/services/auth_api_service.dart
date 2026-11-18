import 'package:dio/dio.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/login_models.dart';

/// 로그인. **공개 Client**로만 보낸다(토큰이 필요 없고, 보호 Client의 Interceptor를 거칠 이유도 없다).
class AuthApiService {
  AuthApiService(this._publicDio);

  final Dio _publicDio;

  Future<LoginResult> login(LoginRequest request) async {
    final response = await _publicDio.post<Object?>(
      '/auth/login',
      data: request.toJson(),
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('로그인 응답 형식이 올바르지 않습니다.');
    }
    final common = CommonResponse<LoginResult>.fromJson(
      data,
      (value) => LoginResult.fromJson(value as Map<String, dynamic>),
    );
    final result = common.result;
    if (result == null) throw StateError('로그인 result가 없습니다.');
    return result;
  }
}
