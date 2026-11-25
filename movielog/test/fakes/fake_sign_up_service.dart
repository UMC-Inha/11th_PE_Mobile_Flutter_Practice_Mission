import 'dart:async';

import 'package:dio/dio.dart';

import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/sign_up_service.dart';

/// 실제 워크북 서버 대신 미리 정해 둔 값을 돌려주는 테스트용 Service입니다.
class FakeSignUpService extends SignUpService {
  FakeSignUpService({
    this.takenNicknames = const {},
    this.takenEmails = const {},
    this.fail = false,
    this.createdMemberId = 101,
  }) : super(Dio());

  final Set<String> takenNicknames;
  final Set<String> takenEmails;

  /// true면 중복 확인에서 통신 실패(DioException)를 던집니다.
  bool fail;

  /// 가입 성공 시 result.memberId로 돌려줄 값입니다. null이면 result가 비어 있습니다.
  int? createdMemberId;

  /// 설정하면 회원가입 POST가 이 상태 코드·공통 오류 body로 실패합니다.
  int? signUpFailStatus;
  String signUpFailMessage = '이미 사용 중인 이메일입니다.';

  /// 설정하면 응답을 이 Completer가 끝날 때까지 늦춥니다. (통신 중 상태 재현)
  Completer<void>? gate;

  final nicknameRequests = <String>[];
  final emailRequests = <String>[];
  final signUpRequests = <Map<String, dynamic>>[];

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

  @override
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    signUpRequests.add(request.toJson());
    await gate?.future;
    final status = signUpFailStatus;
    if (status != null) {
      final options = RequestOptions(path: '/v6/members', method: 'POST');
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: options,
          statusCode: status,
          data: {
            'isSuccess': false,
            'code': 'COMMON$status',
            'message': signUpFailMessage,
            'result': null,
          },
        ),
      );
    }
    final id = createdMemberId;
    return CommonResponse<SignUpResult>(
      isSuccess: true,
      code: 'COMMON201',
      message: '회원가입에 성공했습니다.',
      result: id == null
          ? null
          : SignUpResult(
              memberId: id,
              email: request.email.trim(),
              nickname: request.nickname.trim(),
            ),
    );
  }

  Future<void> _respond() async {
    await gate?.future;
    if (fail) {
      throw DioException(
        requestOptions: RequestOptions(path: '/v6/members'),
        type: DioExceptionType.connectionError,
      );
    }
  }
}
