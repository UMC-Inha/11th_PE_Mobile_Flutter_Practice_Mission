import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/edit_profile_view_model.dart';

import 'support.dart';

void main() {
  late FakeMemberApiService memberApi;
  late FakeTokenStorage storage;
  late AuthViewModel auth;
  late EditProfileViewModel vm;

  setUp(() async {
    memberApi = FakeMemberApiService();
    storage = FakeTokenStorage();
    auth = AuthViewModel(FakeAuthApiService(), memberApi, storage);
    await auth.login('kevin@umc.com', 'Password1234!');
    await auth.loadMember();
    memberApi.fetchCalls = 0;
    vm = EditProfileViewModel(memberApi, auth);
  });

  tearDown(() {
    vm.dispose();
    auth.dispose();
  });

  test('닉네임은 2~12자만 통과한다(앞뒤 공백은 세지 않는다)', () {
    expect(vm.validateNickname('가'), isNotNull);
    expect(vm.validateNickname(' 가 '), isNotNull);
    expect(vm.validateNickname('가' * 13), isNotNull);
    expect(vm.validateNickname('가나'), isNull);
    expect(vm.validateNickname('가' * 12), isNull);
    expect(vm.validateNickname('  새 닉네임  '), isNull);
  });

  test('저장하지 않은 변경 여부는 trim한 값을 현재 닉네임과 비교한다', () {
    expect(vm.hasChanges('케빈'), isFalse);
    expect(vm.hasChanges('  케빈  '), isFalse);
    expect(vm.hasChanges('케빈2'), isTrue);
    expect(vm.hasChanges(''), isTrue);
  });

  test('성공: trim한 닉네임을 보내고 내 정보(마이페이지가 보는 값)가 바뀐다', () async {
    final seen = <EditProfileStatus>[];
    vm.addListener(() => seen.add(vm.status));

    final ok = await vm.save('  새닉네임 ');

    expect(ok, isTrue);
    expect(seen, [EditProfileStatus.saving, EditProfileStatus.success]);
    expect(memberApi.updatedNicknames, ['새닉네임']);
    expect(auth.member?.nickname, '새닉네임');
    expect(auth.member?.email, 'kevin@umc.com', reason: '이메일은 바뀌지 않는다');
    expect(vm.nicknameError, isNull);
    expect(vm.message, isNull);
  });

  test('현재 닉네임과 같으면 요청 없이 성공으로 끝난다', () async {
    final ok = await vm.save('케빈');
    expect(ok, isTrue);
    expect(vm.status, EditProfileStatus.success);
    expect(memberApi.updatedNicknames, isEmpty);
  });

  test('길이가 맞지 않으면 서버에 보내지 않고 입력칸 오류로 알린다', () async {
    for (final input in ['가', ' ', '가' * 13]) {
      final ok = await vm.save(input);
      expect(ok, isFalse, reason: '"$input"');
      expect(vm.nicknameError, '닉네임은 2~12자로 입력해 주세요.');
    }
    expect(memberApi.updatedNicknames, isEmpty);
    expect(auth.member?.nickname, '케빈');
  });

  test('이미 쓰는 닉네임(409)은 입력칸 오류이고 내 정보·로그인 상태는 그대로다', () async {
    final ok = await vm.save('수현'); // takenNicknames에 있다

    expect(ok, isFalse);
    expect(vm.status, EditProfileStatus.failure);
    expect(vm.nicknameError, '이미 사용 중인 닉네임이에요.');
    expect(vm.message, isNull, reason: '필드 문제는 Snackbar가 아니라 입력칸에 붙인다');
    expect(auth.member?.nickname, '케빈');
    expect(auth.status, AuthStatus.signedIn);

    // 다시 입력하기 시작하면 오류 문구가 지워진다.
    vm.onNicknameChanged();
    expect(vm.nicknameError, isNull);
  });

  test('서버가 형식을 거부(COMMON400)하면 그 message를 입력칸에 붙인다', () async {
    memberApi.updateFailure = apiFailure(
      '/members/me',
      400,
      code: 'COMMON400',
      message: '닉네임에 사용할 수 없는 문자가 있습니다.',
    );
    await vm.save('새닉네임');
    expect(vm.nicknameError, '닉네임에 사용할 수 없는 문자가 있습니다.');
  });

  test('회원을 찾지 못하면(MEMBER404_1) 안내만 하고 로그아웃하지 않는다', () async {
    memberApi.updateFailure = apiFailure(
      '/members/me',
      404,
      code: 'MEMBER404_1',
      message: '존재하지 않는 회원입니다.',
    );
    await vm.save('새닉네임');
    expect(vm.message, '회원 정보를 찾을 수 없어요.');
    expect(auth.status, AuthStatus.signedIn);
  });

  test('통신 실패는 네트워크 문구이고 토큰을 지우지 않는다', () async {
    memberApi.updateFailure = networkFailure('/members/me');
    final ok = await vm.save('새닉네임');

    expect(ok, isFalse);
    expect(vm.message, '네트워크 상태를 확인하고 다시 시도해 주세요.');
    expect(vm.nicknameError, isNull);
    expect(auth.status, AuthStatus.signedIn);
    expect(storage.token, isNotNull);
    expect(storage.deletes, 0);
    expect(auth.member?.nickname, '케빈');
  });

  test('서버가 응답했지만 실패한 경우(500)는 네트워크 탓으로 돌리지 않는다', () async {
    memberApi.updateFailure = apiFailure(
      '/members/me',
      500,
      code: 'COMMON500',
      message: '서버 오류',
    );
    await vm.save('새닉네임');
    expect(vm.message, '요청에 실패했어요. 잠시 후 다시 시도해 주세요.');
    expect(vm.message, isNot(contains('네트워크')));
    expect(auth.status, AuthStatus.signedIn);
  });

  test('토큰 만료(AUTH401_3)면 세션을 정리하고 로그인 화면이 만료를 안내하게 한다', () async {
    memberApi.updateFailure = apiFailure(
      '/members/me',
      401,
      code: 'AUTH401_3',
      message: '토큰이 만료되었습니다.',
    );
    final ok = await vm.save('새닉네임');

    expect(ok, isFalse);
    expect(auth.status, AuthStatus.signedOut);
    expect(auth.sessionExpired, isTrue);
    expect(storage.token, isNull);
  });

  test('저장 중 중복 호출은 무시한다', () async {
    memberApi.updateGate = Completer<void>();
    final first = vm.save('새닉네임');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(vm.status, EditProfileStatus.saving);

    expect(await vm.save('새닉네임'), isFalse);
    expect(memberApi.updatedNicknames, hasLength(1));

    memberApi.updateGate!.complete();
    expect(await first, isTrue);
  });

  test('저장 중 로그아웃하면 늦게 온 성공 응답이 내 정보를 다시 쓰지 않는다', () async {
    memberApi.updateGate = Completer<void>();
    final pending = vm.save('새닉네임');
    await Future<void>.delayed(const Duration(milliseconds: 150));

    await auth.logout();
    memberApi.updateGate!.complete();
    final ok = await pending;

    expect(ok, isFalse);
    expect(auth.member, isNull);
    expect(auth.status, AuthStatus.signedOut);
  });

  test('화면이 사라진 뒤 도착한 응답은 알림을 보내지 않는다', () async {
    final local = EditProfileViewModel(memberApi, auth);
    memberApi.updateGate = Completer<void>();
    final pending = local.save('새닉네임');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    local.dispose();
    memberApi.updateGate!.complete();
    await pending; // dispose 뒤 notifyListeners가 불리면 예외가 난다
  });
}
