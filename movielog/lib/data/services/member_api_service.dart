import 'package:dio/dio.dart';
import 'package:movielog/data/models/member_info.dart';

/// 내 정보 조회·수정. **보호 Client**로 보낸다(Interceptor가 Bearer를 붙인다).
class MemberApiService {
  MemberApiService(this._authDio);

  final Dio _authDio;

  Future<MemberInfo> fetchMe() async {
    final response = await _authDio.get<Object?>('/members/me');
    return parseMemberInfo(response.data);
  }

  Future<MemberInfo> updateNickname(String nickname) async {
    final response = await _authDio.patch<Object?>(
      '/members/me',
      data: {'nickname': nickname},
    );
    return parseMemberInfo(response.data);
  }
}
