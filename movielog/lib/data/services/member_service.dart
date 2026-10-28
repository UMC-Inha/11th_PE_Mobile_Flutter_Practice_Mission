import 'package:dio/dio.dart';

import '../models/member_rating_dto.dart';

/// MovieLog Spring 서버의 회원 API를 호출하고 응답 JSON을 Dart 값으로 변환합니다.
class MemberService {
  MemberService(this._dio);
  final Dio _dio;

  /// 닉네임을 사용할 수 있으면 true를 반환합니다.
  Future<bool> isNicknameAvailable(String nickname) async {
    final response = await _dio.get(
      '/members/nickname/${Uri.encodeComponent(nickname)}',
    );
    return (response.data as Map<String, dynamic>)['available'] as bool;
  }

  /// 이메일을 사용할 수 있으면 true를 반환합니다.
  Future<bool> isEmailAvailable(String email) async {
    final response = await _dio.get(
      '/members/email/${Uri.encodeComponent(email)}',
    );
    return (response.data as Map<String, dynamic>)['available'] as bool;
  }

  Future<List<MemberRatingDto>> fetchRatings(int memberId) async {
    final response = await _dio.get('/members/$memberId/ratings');
    final list = response.data as List<dynamic>;
    return list
        .map((item) => MemberRatingDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
