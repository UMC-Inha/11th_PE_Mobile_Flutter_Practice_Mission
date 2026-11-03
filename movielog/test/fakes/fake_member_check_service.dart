import 'dart:async';

import 'package:dio/dio.dart';

import 'package:movielog/data/services/member_check_service.dart';

/// 실제 워크북 서버 대신 미리 정해 둔 값을 돌려주는 테스트용 Service입니다.
class FakeMemberCheckService extends MemberCheckService {
  FakeMemberCheckService({
    this.takenNicknames = const {},
    this.takenEmails = const {},
    this.fail = false,
  }) : super(Dio());

  final Set<String> takenNicknames;
  final Set<String> takenEmails;

  /// true면 통신 실패(DioException)를 던집니다.
  bool fail;

  /// 설정하면 응답을 이 Completer가 끝날 때까지 늦춥니다. (통신 중 상태 재현)
  Completer<void>? gate;

  final nicknameRequests = <String>[];
  final emailRequests = <String>[];

  @override
  Future<bool> checkNickname(String nickname) async {
    nicknameRequests.add(nickname);
    await _respond();
    return !takenNicknames.contains(nickname);
  }

  @override
  Future<bool> checkEmail(String email) async {
    emailRequests.add(email);
    await _respond();
    return !takenEmails.contains(email);
  }

  Future<void> _respond() async {
    await gate?.future;
    if (fail) {
      throw DioException(
        requestOptions: RequestOptions(path: '/v5/members'),
        type: DioExceptionType.connectionError,
      );
    }
  }
}
