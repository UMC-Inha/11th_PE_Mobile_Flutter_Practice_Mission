import 'package:dio/dio.dart';

import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/view_models/auth_view_model.dart';

/// 테스트용 메모리 토큰 저장소입니다.
class FakeTokenStorage implements TokenStorage {
  String? token;

  @override
  Future<void> saveAccessToken(String token) async => this.token = token;

  @override
  Future<String?> readAccessToken() async => token;

  @override
  Future<void> deleteAccessToken() async => token = null;
}

class FakeAuthApiService extends AuthApiService {
  FakeAuthApiService() : super(Dio());

  @override
  Future<LoginResult> login(LoginRequest request) async {
    return const LoginResult(nickname: '무비러버', accessToken: 'test-token');
  }
}

class FakeMemberApiService extends MemberApiService {
  FakeMemberApiService() : super(Dio());

  @override
  Future<MemberInfo> fetchMe() async {
    return MemberInfo(
      email: 'movielover@movielog.com',
      nickname: '무비러버',
      createdAt: DateTime.utc(2026, 10, 10),
    );
  }
}

/// 로그인과 내 정보 불러오기를 마친 AuthViewModel입니다.
Future<AuthViewModel> signedInAuth() async {
  final auth = AuthViewModel(
    FakeAuthApiService(),
    FakeMemberApiService(),
    FakeTokenStorage(),
  );
  await auth.login('movielover@movielog.com', 'Password1!');
  await auth.loadMember();
  return auth;
}
