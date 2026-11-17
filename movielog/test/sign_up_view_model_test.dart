import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/models/check_result.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

import 'fakes/fake_member_check_service.dart';

void main() {
  test('CheckResult는 공통 Wrapper 없이 응답 body를 그대로 변환한다', () {
    expect(CheckResult.fromJson({'available': true}).available, isTrue);
    expect(CheckResult.fromJson({'available': false}).available, isFalse);
  });

  test('확인 전 → 통신 중 → 사용 가능 순서로 상태가 바뀐다', () async {
    final service = FakeMemberCheckService()..gate = Completer<void>();
    final viewModel = SignUpViewModel(service);

    viewModel.onNicknameChanged('무비러버');
    expect(viewModel.nicknameCheckStatus, CheckStatus.idle);

    final pending = viewModel.checkNickname('무비러버');
    expect(viewModel.nicknameCheckStatus, CheckStatus.checking);
    expect(viewModel.canCheckNickname, isFalse);

    service.gate!.complete();
    await pending;
    expect(viewModel.nicknameCheckStatus, CheckStatus.available);
    expect(viewModel.nicknameErrorText, isNull);
  });

  test('중복 응답과 통신 실패는 서로 다른 상태·문구로 구분한다', () async {
    final service = FakeMemberCheckService(takenNicknames: {'무비러버'});
    final viewModel = SignUpViewModel(service);

    viewModel.onNicknameChanged('무비러버');
    await viewModel.checkNickname('무비러버');
    expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
    final duplicatedText = viewModel.nicknameErrorText;

    service.fail = true;
    viewModel.onNicknameChanged('다른닉네임');
    await viewModel.checkNickname('다른닉네임');
    expect(viewModel.nicknameCheckStatus, CheckStatus.error);
    expect(viewModel.nicknameErrorText, isNotNull);
    expect(viewModel.nicknameErrorText, isNot(duplicatedText));
    // 통신 실패는 다시 시도할 수 있습니다.
    expect(viewModel.canCheckNickname, isTrue);
  });

  test('입력을 바꾸면 이전 결과가 무효화되고, 중복이었던 값을 다시 입력하면 요청 없이 중복 상태로 돌아온다', () async {
    final service = FakeMemberCheckService(takenNicknames: {'무비러버'});
    final viewModel = SignUpViewModel(service);

    viewModel.onNicknameChanged('무비러버');
    await viewModel.checkNickname('무비러버');
    expect(viewModel.canCheckNickname, isFalse);

    viewModel.onNicknameChanged('무비러');
    expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
    expect(viewModel.nicknameErrorText, isNull);
    expect(viewModel.canCheckNickname, isTrue);

    // 공백 차이는 같은 값으로 봅니다.
    viewModel.onNicknameChanged(' 무비러버 ');
    expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
    expect(viewModel.nicknameErrorText, '이미 사용 중인 닉네임입니다.');
    expect(viewModel.canCheckNickname, isFalse);
    expect(service.nicknameRequests, ['무비러버']);
  });

  test('응답 도착 전에 입력이 바뀌면 이전 응답을 무시한다', () async {
    final service = FakeMemberCheckService()..gate = Completer<void>();
    final viewModel = SignUpViewModel(service);

    viewModel.onNicknameChanged('무비러버');
    final pending = viewModel.checkNickname('무비러버');
    viewModel.onNicknameChanged('무비러버2');

    service.gate!.complete();
    await pending;
    expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
  });

  test('닉네임과 이메일 결과는 서로 영향을 주지 않는다', () async {
    final service = FakeMemberCheckService(takenEmails: {'a@b.com'});
    final viewModel = SignUpViewModel(service);

    viewModel.onNicknameChanged('무비러버');
    viewModel.onEmailChanged('a@b.com');
    await viewModel.checkNickname('무비러버');
    await viewModel.checkEmail('a@b.com');

    expect(viewModel.nicknameCheckStatus, CheckStatus.available);
    expect(viewModel.emailCheckStatus, CheckStatus.duplicated);
  });
}
