import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/view_models/auth_view_model.dart';

import 'support.dart';

void main() {
  late FakeAuthApiService authApi;
  late FakeMemberApiService memberApi;
  late FakeTokenStorage storage;
  late AuthViewModel vm;

  const email = 'kevin@umc.com';
  const password = 'Password1234!';

  setUp(() {
    authApi = FakeAuthApiService();
    memberApi = FakeMemberApiService();
    storage = FakeTokenStorage();
    vm = AuthViewModel(authApi, memberApi, storage);
  });

  tearDown(() => vm.dispose());

  group('login', () {
    test(
      '성공: authenticating → signedIn이고 토큰은 저장하되 비밀번호는 어디에도 남기지 않는다',
      () async {
        final seen = <AuthStatus>[];
        vm.addListener(() => seen.add(vm.status));

        await vm.login(email, password);

        expect(seen, [AuthStatus.authenticating, AuthStatus.signedIn]);
        expect(vm.status, AuthStatus.signedIn);
        expect(storage.token, authApi.lastIssuedToken);
        expect(storage.token, isNot(contains(password)));
        expect(vm.message, isNull);
        expect(vm.sessionExpired, isFalse);
        // 내 정보는 로그인에서 부르지 않는다(MainShell이 loadMember로 한 번 부른다).
        expect(memberApi.fetchCalls, 0);
        expect(vm.member, isNull);
      },
    );

    test('이메일·비밀번호 오류(AUTH401_1)는 Form 오류일 뿐 만료 처리가 아니다', () async {
      await vm.login(email, 'wrong');

      expect(vm.status, AuthStatus.signedOut);
      expect(vm.message, '이메일 또는 비밀번호를 확인해 주세요.');
      expect(vm.sessionExpired, isFalse);
      expect(storage.token, isNull);
      expect(storage.deletes, 0, reason: '저장된 것이 없는데 지우려 하지 않는다');
    });

    test('통신 실패·서버 오류·저장 실패·응답 형식 오류를 서로 다른 문구로 나눈다', () async {
      final messages = <String>{};

      authApi.failure = networkFailure('/auth/login');
      await vm.login(email, password);
      messages.add(vm.message!);
      expect(vm.message, contains('네트워크'));

      authApi.failure = apiFailure(
        '/auth/login',
        500,
        code: 'COMMON500',
        message: '서버 오류',
      );
      await vm.login(email, password);
      messages.add(vm.message!);

      authApi.failure = StateError('로그인 result가 없습니다.');
      await vm.login(email, password);
      messages.add(vm.message!);

      authApi.failure = null;
      storage.failWrite = true;
      await vm.login(email, password);
      messages.add(vm.message!);
      expect(vm.message, '로그인 정보를 안전하게 저장하지 못했어요.');
      expect(storage.token, isNull);
      expect(vm.status, AuthStatus.signedOut);

      // AUTH401_1의 문구와도 다르다.
      messages.add('이메일 또는 비밀번호를 확인해 주세요.');
      expect(messages, hasLength(5), reason: '문구가 서로 겹치지 않는다');
    });

    test('서버가 입력을 거부(COMMON400)하면 그 message를 그대로 보여준다', () async {
      authApi.failure = apiFailure(
        '/auth/login',
        400,
        code: 'COMMON400',
        message: '이메일 형식이 올바르지 않습니다.',
      );
      await vm.login('not-an-email', password);
      expect(vm.message, '이메일 형식이 올바르지 않습니다.');
    });

    test('요청 중 중복 탭은 무시한다', () async {
      authApi.gate = Completer<void>();
      final first = vm.login(email, password);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(vm.status, AuthStatus.authenticating);

      await vm.login(email, password);
      expect(authApi.requests, hasLength(1));

      authApi.gate!.complete();
      await first;
      expect(vm.status, AuthStatus.signedIn);
    });

    test('로그인 요청 중에 로그아웃되면 늦게 온 성공 응답은 토큰을 저장하지 않는다', () async {
      authApi.gate = Completer<void>();
      final pending = vm.login(email, password);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      await vm.logout();
      authApi.gate!.complete();
      await pending;

      expect(vm.status, AuthStatus.signedOut);
      expect(storage.token, isNull);
      expect(storage.writes, 0);
    });

    test('새 로그인은 이전 만료 표시와 내 정보를 지운다', () async {
      await vm.login(email, password);
      await vm.loadMember();
      await vm.expireSession();
      expect(vm.sessionExpired, isTrue);

      await vm.login(email, password);
      expect(vm.sessionExpired, isFalse);
      expect(vm.member, isNull);
      expect(vm.status, AuthStatus.signedIn);
    });

    test('토큰을 지우는 중에는 새 로그인을 막는다', () async {
      await vm.login(email, password);
      final before = authApi.requests.length;
      final clearing = vm.logout(); // 동기 구간에서 storageCleanupInProgress가 켜진다
      expect(vm.storageCleanupInProgress, isTrue);
      await vm.login(email, password);
      expect(authApi.requests, hasLength(before));
      await clearing;
      expect(vm.storageCleanupInProgress, isFalse);
    });
  });

  group('restoreSession: 앱 재시작', () {
    test('저장된 토큰이 없으면 서버에 묻지 않고 signedOut(만료 아님)', () async {
      await vm.restoreSession();
      expect(vm.status, AuthStatus.signedOut);
      expect(vm.sessionExpired, isFalse);
      expect(memberApi.fetchCalls, 0);
    });

    test('토큰이 있어도 GET me가 성공하기 전에는 signedIn이 아니다', () async {
      storage.token = 'stored';
      memberApi.meGate = Completer<void>();
      final seen = <AuthStatus>[];
      vm.addListener(() => seen.add(vm.status));

      final restoring = vm.restoreSession();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(vm.status, AuthStatus.initializing);
      expect(seen, isNot(contains(AuthStatus.signedIn)));
      expect(vm.member, isNull);

      memberApi.meGate!.complete();
      await restoring;
      expect(vm.status, AuthStatus.signedIn);
      expect(vm.member?.nickname, '케빈');
      expect(vm.memberStatus, MemberLoadStatus.success);
      expect(memberApi.fetchCalls, 1);
    });

    test('토큰 무효·만료·없음(AUTH401_2/3/4)이면 세션을 정리하고 만료로 표시한다', () async {
      for (final code in ['AUTH401_2', 'AUTH401_3', 'AUTH401_4']) {
        storage.token = 'stored';
        storage.deletes = 0;
        memberApi.meFailure = apiFailure(
          '/members/me',
          401,
          code: code,
          message: '토큰 문제',
        );
        await vm.restoreSession();

        expect(vm.status, AuthStatus.signedOut, reason: code);
        expect(vm.sessionExpired, isTrue, reason: code);
        expect(storage.token, isNull, reason: code);
        expect(storage.deletes, 1, reason: code);
        vm.consumeSessionExpired();
      }
    });

    test('네트워크 실패는 로그아웃이 아니다: retryRequired이고 토큰은 지우지 않으며 재시도로 복구된다', () async {
      storage.token = 'stored';
      memberApi.meFailure = networkFailure('/members/me');

      await vm.restoreSession();

      expect(vm.status, AuthStatus.retryRequired);
      expect(vm.message, '로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.');
      expect(storage.token, 'stored');
      expect(storage.deletes, 0);
      expect(vm.sessionExpired, isFalse);

      // 재시도 버튼 = restoreSession
      memberApi.meFailure = null;
      await vm.restoreSession();
      expect(vm.status, AuthStatus.signedIn);
      expect(storage.token, 'stored');
    });

    test('서버 오류(500)·권한 오류(403)도 토큰을 지우지 않고 재시도 상태로 둔다', () async {
      storage.token = 'stored';
      for (final status in [500, 403]) {
        memberApi.meFailure = apiFailure(
          '/members/me',
          status,
          code: status == 403 ? 'RATING403_1' : 'COMMON500',
          message: '거절',
        );
        await vm.restoreSession();
        expect(vm.status, AuthStatus.retryRequired, reason: '$status');
        expect(storage.token, 'stored');
      }
    });

    test('로그인 입력 오류 code(AUTH401_1)는 세션 만료로 보지 않는다', () async {
      storage.token = 'stored';
      memberApi.meFailure = apiFailure(
        '/members/me',
        401,
        code: 'AUTH401_1',
        message: '이상한 응답',
      );
      await vm.restoreSession();
      expect(vm.status, AuthStatus.retryRequired);
      expect(storage.token, 'stored');
      expect(vm.sessionExpired, isFalse);
    });

    test('저장소를 읽지 못하면 서버에 묻지 않고 retryRequired(저장소 문구)', () async {
      storage.failRead = true;
      await vm.restoreSession();
      expect(vm.status, AuthStatus.retryRequired);
      expect(vm.message, '인증 저장소를 읽지 못했어요. 다시 시도해 주세요.');
      expect(memberApi.fetchCalls, 0);
    });

    test('복원 중에 로그아웃되면 늦게 온 응답이 상태를 되살리지 못한다', () async {
      storage.token = 'stored';
      memberApi.meGate = Completer<void>();
      final restoring = vm.restoreSession();
      await Future<void>.delayed(const Duration(milliseconds: 150));

      await vm.logout();
      memberApi.meGate!.complete();
      await restoring;

      expect(vm.status, AuthStatus.signedOut);
      expect(vm.member, isNull);
      expect(storage.token, isNull);
    });
  });

  group('loadMember', () {
    test('로그인 전에는 호출해도 서버에 묻지 않는다', () async {
      await vm.loadMember();
      expect(memberApi.fetchCalls, 0);
      expect(vm.memberStatus, MemberLoadStatus.idle);
    });

    test('불러와서 보관하고, 이미 있으면 다시 부르지 않으며 force면 다시 부른다', () async {
      await vm.login(email, password);
      final seen = <MemberLoadStatus>[];
      vm.addListener(() => seen.add(vm.memberStatus));

      await vm.loadMember();
      expect(seen, [MemberLoadStatus.loading, MemberLoadStatus.success]);
      expect(vm.member?.email, email);

      await vm.loadMember();
      expect(memberApi.fetchCalls, 1);

      await vm.loadMember(force: true);
      expect(memberApi.fetchCalls, 2);
    });

    test('동시에 여러 번 불러도 한 번만 요청한다', () async {
      await vm.login(email, password);
      memberApi.meGate = Completer<void>();
      final first = vm.loadMember();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await vm.loadMember();
      await vm.loadMember(force: true);
      expect(memberApi.fetchCalls, 1);
      memberApi.meGate!.complete();
      await first;
    });

    test('만료(AUTH401_2/3/4)면 세션을 정리하고 signedOut이 된다', () async {
      for (final code in ['AUTH401_2', 'AUTH401_3', 'AUTH401_4']) {
        await vm.login(email, password);
        memberApi.meFailure = apiFailure(
          '/members/me',
          401,
          code: code,
          message: '만료',
        );
        await vm.loadMember();

        expect(vm.status, AuthStatus.signedOut, reason: code);
        expect(vm.sessionExpired, isTrue, reason: code);
        expect(storage.token, isNull, reason: code);
        memberApi.meFailure = null;
        vm.consumeSessionExpired();
      }
    });

    test('네트워크 실패는 로그아웃하지 않고 error로 남겨 재시도할 수 있다', () async {
      await vm.login(email, password);
      memberApi.meFailure = networkFailure('/members/me');

      await vm.loadMember();
      expect(vm.status, AuthStatus.signedIn);
      expect(vm.memberStatus, MemberLoadStatus.error);
      expect(vm.message, '내 정보를 불러오지 못했어요.');
      expect(storage.token, isNotNull);

      memberApi.meFailure = null;
      await vm.loadMember(force: true);
      expect(vm.memberStatus, MemberLoadStatus.success);
      expect(vm.member, isNotNull);
    });

    test('로그아웃 뒤에 늦게 온 응답은 새 상태에 반영되지 않는다', () async {
      await vm.login(email, password);
      memberApi.meGate = Completer<void>();
      final loading = vm.loadMember();
      await Future<void>.delayed(const Duration(milliseconds: 150));

      await vm.logout();
      memberApi.meGate!.complete();
      await loading;

      expect(vm.member, isNull);
      expect(vm.status, AuthStatus.signedOut);
    });
  });

  group('logout · expireSession · sessionVersion', () {
    test('직접 로그아웃: 토큰·내 정보를 지우고 만료 안내는 켜지 않는다', () async {
      await vm.login(email, password);
      await vm.loadMember();
      final version = vm.sessionVersion;

      await vm.logout();

      expect(vm.status, AuthStatus.signedOut);
      expect(vm.member, isNull);
      expect(vm.memberStatus, MemberLoadStatus.idle);
      expect(storage.token, isNull);
      expect(vm.sessionExpired, isFalse);
      expect(vm.sessionVersion, greaterThan(version));
    });

    test('토큰 저장이 끝나기 전에 로그아웃해도 저장이 끝난 뒤 지운다(토큰이 남지 않는다)', () async {
      storage.writeGate = Completer<void>();
      final logging = vm.login(email, password);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(storage.writes, 1);

      final clearing = vm.logout();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(storage.deletes, 0, reason: '진행 중인 저장을 기다린다');

      storage.writeGate!.complete();
      await clearing;
      await logging;
      expect(storage.token, isNull);
      expect(vm.status, AuthStatus.signedOut);
    });

    test('토큰 삭제에 실패해도 signedOut이 되고 사용자에게 알린다', () async {
      await vm.login(email, password);
      storage.failDelete = true;
      await vm.logout();
      expect(vm.status, AuthStatus.signedOut);
      expect(vm.message, contains('지우지 못했어요'));
    });

    test('expireSession: 현재 세션이면 한 번 정리하고 만료로 표시한다', () async {
      await vm.login(email, password);
      await vm.expireSession(forVersion: vm.sessionVersion);
      expect(vm.status, AuthStatus.signedOut);
      expect(vm.sessionExpired, isTrue);
      expect(storage.token, isNull);
    });

    test('같은 세션에서 동시에 여러 요청이 401을 받아도 정리·알림은 한 번이다', () async {
      await vm.login(email, password);
      final version = vm.sessionVersion;
      var notifications = 0;
      vm.addListener(() => notifications++);

      await Future.wait([
        vm.expireSession(forVersion: version),
        vm.expireSession(forVersion: version),
        vm.expireSession(forVersion: version),
      ]);

      expect(storage.deletes, 1);
      // signedOut 전환 알림 + 삭제 마무리 알림 외에 더 늘지 않는다.
      expect(notifications, lessThanOrEqualTo(2));
    });

    test('이전 세션에서 늦게 도착한 401은 새 로그인을 지우지 못한다', () async {
      await vm.login(email, password);
      final oldVersion = vm.sessionVersion; // 이 세션에서 보낸 요청의 version
      await vm.logout();
      await vm.login(email, password); // 새 로그인(다른 세션)
      final newToken = storage.token;
      expect(vm.status, AuthStatus.signedIn);

      await vm.expireSession(forVersion: oldVersion); // 늦은 401

      expect(vm.status, AuthStatus.signedIn);
      expect(vm.sessionExpired, isFalse);
      expect(storage.token, newToken);
    });

    test('로그아웃 상태에서 도착한 401은 만료 안내를 켜지 않는다', () async {
      await vm.login(email, password);
      final version = vm.sessionVersion;
      await vm.logout();
      await vm.expireSession(forVersion: version);
      await vm.expireSession();
      expect(vm.sessionExpired, isFalse);
    });

    test('consumeSessionExpired는 안내를 꺼서 반복되지 않게 한다', () async {
      await vm.login(email, password);
      await vm.expireSession();
      expect(vm.sessionExpired, isTrue);
      vm.consumeSessionExpired();
      expect(vm.sessionExpired, isFalse);
    });

    test('updateMember는 로그인된 상태에서만 내 정보를 바꾼다', () async {
      vm.updateMember(testMember(nickname: '무시'));
      expect(vm.member, isNull);

      await vm.login(email, password);
      vm.updateMember(testMember(nickname: '새닉네임'));
      expect(vm.member?.nickname, '새닉네임');
      expect(vm.memberStatus, MemberLoadStatus.success);
    });

    test('statusListenable은 상태가 바뀔 때만 알린다(내 정보·문구 변경에는 알리지 않는다)', () async {
      final seen = <AuthStatus>[];
      vm.statusListenable.addListener(
        () => seen.add(vm.statusListenable.value),
      );

      await vm.login(email, password);
      expect(seen, [AuthStatus.authenticating, AuthStatus.signedIn]);

      // 같은 signedIn 상태에서 내 정보가 바뀌거나 불러와져도 Router를 다시 돌리지 않는다.
      await vm.loadMember();
      vm.updateMember(testMember(nickname: '새닉네임'));
      expect(seen, [AuthStatus.authenticating, AuthStatus.signedIn]);

      await vm.logout();
      expect(seen.last, AuthStatus.signedOut);
    });

    test('dispose 뒤에 도착한 응답은 상태를 건드리지 않는다', () async {
      final local = AuthViewModel(authApi, memberApi, storage);
      authApi.gate = Completer<void>();
      final pending = local.login(email, password);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      local.dispose();
      authApi.gate!.complete();
      await pending; // dispose 뒤 notifyListeners가 불리면 여기서 예외가 난다
      expect(storage.writes, 0);
    });
  });
}
