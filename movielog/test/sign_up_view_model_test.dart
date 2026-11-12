import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

import 'support.dart';

void main() {
  late FakeMovieLogApiService api;
  late SignUpViewModel vm;
  late int notifyCount;

  setUp(() {
    api = FakeMovieLogApiService();
    vm = SignUpViewModel(api);
    notifyCount = 0;
    vm.addListener(() => notifyCount++);
  });

  /// 화면에서 글자를 입력하고 중복 확인 버튼을 누르는 것과 같은 순서.
  Future<void> typeAndCheckNickname(String value) async {
    vm.onNicknameChanged(value);
    await vm.checkNickname(value);
  }

  group('닉네임 중복 확인 상태', () {
    test('idle → checking → available 순서로 바뀐다', () async {
      final seen = <CheckStatus>[];
      vm.addListener(() => seen.add(vm.nicknameCheckStatus));
      expect(vm.nicknameCheckStatus, CheckStatus.idle);

      await typeAndCheckNickname('케빈');

      expect(seen, [
        CheckStatus.idle, // 입력 변경(이미 idle이어도 입력 처리 때 한 번 알린다)
        CheckStatus.checking,
        CheckStatus.available,
      ]);
      expect(vm.nicknameErrorText, isNull);
      expect(vm.isNicknameConfirmed('케빈'), isTrue);
    });

    test('통신 중에는 다시 확인할 수 없다', () async {
      api.gate = Completer<void>();
      vm.onNicknameChanged('케빈');
      final pending = vm.checkNickname('케빈');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(vm.nicknameCheckStatus, CheckStatus.checking);
      expect(vm.canCheckNickname, isFalse);
      await vm.checkNickname('케빈'); // 무시된다
      expect(api.checkedNicknames, ['케빈']);

      api.gate!.complete();
      await pending;
      expect(vm.nicknameCheckStatus, CheckStatus.available);
      expect(vm.canCheckNickname, isTrue);
    });

    test('서버가 중복이라고 답하면 duplicated, 즉시 버튼이 막힌다', () async {
      await typeAndCheckNickname('수현');

      expect(vm.nicknameCheckStatus, CheckStatus.duplicated);
      expect(vm.nicknameErrorText, '이미 사용 중인 닉네임이에요.');
      expect(vm.canCheckNickname, isFalse);
      expect(vm.isNicknameConfirmed('수현'), isFalse);
    });

    test('중복 응답(available: false)과 통신 실패는 서로 다른 상태·문구다', () async {
      await typeAndCheckNickname('수현');
      final duplicatedText = vm.nicknameErrorText;

      api.fail = true;
      await typeAndCheckNickname('케빈');

      expect(vm.nicknameCheckStatus, CheckStatus.error);
      expect(vm.nicknameErrorText, isNot(duplicatedText));
      expect(vm.nicknameErrorText, '네트워크 상태를 확인하고 다시 시도해 주세요.');
      // 통신 실패는 같은 값으로 다시 시도할 수 있다.
      expect(vm.canCheckNickname, isTrue);

      api.fail = false;
      await vm.checkNickname('케빈');
      expect(vm.nicknameCheckStatus, CheckStatus.available);
    });

    test('앞뒤 공백은 잘라서 서버에 묻는다', () async {
      await typeAndCheckNickname(' 수현 ');
      expect(api.checkedNicknames, ['수현']);
      expect(vm.nicknameCheckStatus, CheckStatus.duplicated);
    });

    test('입력하지 않은 값이나 비어 있는 값은 서버에 묻지 않는다', () async {
      await vm.checkNickname('케빈'); // onChanged 없이 호출
      await vm.checkNickname('   ');
      expect(api.checkedNicknames, isEmpty);
      expect(vm.nicknameCheckStatus, CheckStatus.idle);
    });
  });

  group('입력 변경으로 이전 결과 무효화', () {
    test('사용 가능 확인 뒤 입력을 바꾸면 idle로 돌아가고 가입 조건이 풀린다', () async {
      await typeAndCheckNickname('케빈');
      expect(vm.isNicknameConfirmed('케빈'), isTrue);

      vm.onNicknameChanged('케빈2');

      expect(vm.nicknameCheckStatus, CheckStatus.idle);
      expect(vm.isNicknameConfirmed('케빈2'), isFalse);
      expect(vm.isNicknameConfirmed('케빈'), isFalse);
    });

    test('통신 실패 뒤에 입력을 바꿔도 idle로 돌아간다', () async {
      api.fail = true;
      await typeAndCheckNickname('케빈');
      expect(vm.nicknameCheckStatus, CheckStatus.error);

      vm.onNicknameChanged('케빈2');
      expect(vm.nicknameCheckStatus, CheckStatus.idle);
      expect(vm.nicknameErrorText, isNull);
    });

    test('기다리던 이전 응답은 입력이 바뀐 뒤 도착해도 무시한다', () async {
      api.gate = Completer<void>();
      vm.onNicknameChanged('수현');
      final pending = vm.checkNickname('수현');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(vm.nicknameCheckStatus, CheckStatus.checking);

      vm.onNicknameChanged('수현2'); // 확인 중에 입력을 바꾼다
      expect(vm.nicknameCheckStatus, CheckStatus.idle);

      api.gate!.complete();
      await pending;
      // '수현'의 중복 응답이 '수현2' 입력에 영향을 주지 않는다.
      expect(vm.nicknameCheckStatus, CheckStatus.idle);
      expect(vm.nicknameErrorText, isNull);
    });

    test('공백만 바뀐 입력은 확인 결과를 지우지 않는다', () async {
      await typeAndCheckNickname('케빈');
      vm.onNicknameChanged('케빈 ');
      expect(vm.nicknameCheckStatus, CheckStatus.available);
      expect(vm.isNicknameConfirmed('케빈 '), isTrue);
    });
  });

  group('Challenge: 중복이었던 값을 기억한다', () {
    test('다른 값으로 고치면 에러가 풀리고 버튼이 다시 눌린다', () async {
      await typeAndCheckNickname('수현');
      expect(vm.canCheckNickname, isFalse);

      vm.onNicknameChanged('수현이');

      expect(vm.nicknameCheckStatus, CheckStatus.idle);
      expect(vm.nicknameErrorText, isNull);
      expect(vm.canCheckNickname, isTrue);
    });

    test('방금 지운 중복 값을 다시 입력하면 서버에 묻지 않고 즉시 에러로 돌아온다', () async {
      await typeAndCheckNickname('수현');
      vm.onNicknameChanged('수현이');
      expect(api.checkedNicknames, ['수현']);

      vm.onNicknameChanged('수현'); // 방금 지운 값과 정확히 같은 문자열

      expect(vm.nicknameCheckStatus, CheckStatus.duplicated);
      expect(vm.nicknameErrorText, '이미 사용 중인 닉네임이에요.');
      expect(vm.canCheckNickname, isFalse);
      // 요청이 나가지 않았다. 버튼이 막혀 있으니 눌러도 마찬가지다.
      await vm.checkNickname('수현');
      expect(api.checkedNicknames, ['수현']);
    });

    test('"마지막으로 확인한 값"이 아니라 "마지막으로 중복이었던 값"을 기억한다', () async {
      await typeAndCheckNickname('수현'); // 중복
      await typeAndCheckNickname('케빈'); // 사용 가능 — 마지막으로 확인한 값은 이제 '케빈'
      expect(vm.nicknameCheckStatus, CheckStatus.available);

      vm.onNicknameChanged('수현');

      expect(vm.nicknameCheckStatus, CheckStatus.duplicated);
      expect(api.checkedNicknames, ['수현', '케빈']);
    });

    test('중복 값 앞뒤 공백만 다른 입력도 같은 값으로 본다', () async {
      await typeAndCheckNickname('수현');
      vm.onNicknameChanged('수현이');
      vm.onNicknameChanged(' 수현 ');
      expect(vm.nicknameCheckStatus, CheckStatus.duplicated);
    });
  });

  group('닉네임과 이메일은 서로 영향을 주지 않는다', () {
    test('닉네임이 중복이어도 이메일 상태는 그대로다', () async {
      await typeAndCheckNickname('수현');
      expect(vm.nicknameCheckStatus, CheckStatus.duplicated);
      expect(vm.emailCheckStatus, CheckStatus.idle);
      expect(vm.canCheckEmail, isTrue);

      vm.onEmailChanged('noco@umc.com');
      await vm.checkEmail('noco@umc.com');
      expect(vm.emailCheckStatus, CheckStatus.duplicated);
      expect(vm.emailErrorText, '이미 가입된 이메일이에요.');

      vm.onEmailChanged('kevin@umc.com');
      expect(vm.emailCheckStatus, CheckStatus.idle);
      // 이메일을 고쳐도 닉네임 중복 상태는 유지된다.
      expect(vm.nicknameCheckStatus, CheckStatus.duplicated);
    });

    test('이메일에도 같은 규칙(무효화·중복 기억)이 적용된다', () async {
      vm.onEmailChanged('noco@umc.com');
      await vm.checkEmail('noco@umc.com');
      vm.onEmailChanged('noco2@umc.com');
      expect(vm.canCheckEmail, isTrue);

      vm.onEmailChanged('noco@umc.com');
      expect(vm.emailCheckStatus, CheckStatus.duplicated);
      expect(vm.canCheckEmail, isFalse);
      expect(api.checkedEmails, ['noco@umc.com']);
    });

    test('이메일 통신 실패는 닉네임 확인 결과를 지우지 않는다', () async {
      await typeAndCheckNickname('케빈');
      api.fail = true;
      vm.onEmailChanged('kevin@umc.com');
      await vm.checkEmail('kevin@umc.com');
      expect(vm.emailCheckStatus, CheckStatus.error);
      expect(vm.nicknameCheckStatus, CheckStatus.available);
      expect(vm.isNicknameConfirmed('케빈'), isTrue);
    });
  });

  test('dispose 뒤에 도착한 응답은 알림을 보내지 않는다', () async {
    api.gate = Completer<void>();
    vm.onNicknameChanged('케빈');
    final pending = vm.checkNickname('케빈');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final before = notifyCount;

    vm.dispose();
    api.gate!.complete();
    await pending; // dispose된 notifier를 건드리면 여기서 예외가 난다

    expect(notifyCount, before);
  });
}
