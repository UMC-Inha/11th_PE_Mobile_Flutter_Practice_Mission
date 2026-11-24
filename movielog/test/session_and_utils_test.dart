import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/session/auth_session_bridge.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/core/utils/map_bounded.dart';
import 'package:movielog/core/utils/safe_notify.dart';
import 'package:movielog/view_models/auth_view_model.dart';

import 'support.dart';

/// AuthViewModel 대신 쓰는 가짜 신호. 값을 바꾸고 알림을 보낸다.
class _Signals extends ChangeNotifier {
  int version = 0;
  String? email;

  void change({int? version, String? email, bool clearEmail = false}) {
    if (version != null) this.version = version;
    if (clearEmail) {
      this.email = null;
    } else if (email != null) {
      this.email = email;
    }
    notifyListeners();
  }
}

class _Notifier extends ChangeNotifier with SafeNotify {}

void main() {
  group('SessionGuard', () {
    test('startSession은 번호를 올리고 그 번호·계정으로만 isCurrent가 참이다', () {
      final guard = SessionGuard();
      final first = guard.startSession('a@umc.com');
      expect(guard.accountId, 'a@umc.com');
      expect(guard.isCurrent(first, 'a@umc.com'), isTrue);
      expect(guard.isCurrent(first, 'b@umc.com'), isFalse, reason: '다른 계정');
      expect(guard.isCurrent(first - 1, 'a@umc.com'), isFalse, reason: '다른 번호');
    });

    test('같은 이메일로 다시 로그인해도 번호가 올라가 이전 세션은 현재가 아니다', () {
      final guard = SessionGuard();
      final first = guard.startSession('a@umc.com');
      final second = guard.startSession('a@umc.com');
      expect(second, greaterThan(first));
      expect(guard.isCurrent(first, 'a@umc.com'), isFalse);
      expect(guard.isCurrent(second, 'a@umc.com'), isTrue);
    });

    test('invalidate는 계정을 비우고 번호를 올려 지금 세션을 무효로 만든다', () {
      final guard = SessionGuard();
      final gen = guard.startSession('a@umc.com');
      guard.invalidate();
      expect(guard.accountId, isNull);
      expect(guard.generation, greaterThan(gen));
      expect(guard.isCurrent(gen, 'a@umc.com'), isFalse);
    });

    test('계정 전환(A → B)이면 A 세션에서 보낸 요청은 현재가 아니다', () {
      final guard = SessionGuard();
      final a = guard.startSession('a@umc.com');
      guard.invalidate();
      final b = guard.startSession('b@umc.com');
      expect(guard.isCurrent(a, 'a@umc.com'), isFalse);
      expect(guard.isCurrent(b, 'b@umc.com'), isTrue);
    });
  });

  group('AuthSessionBridge', () {
    late _Signals signals;
    late AuthSessionBridge bridge;

    setUp(() {
      signals = _Signals();
      bridge = AuthSessionBridge(
        authSignals: signals,
        sessionVersion: () => signals.version,
        verifiedEmail: () => signals.email,
      );
    });

    tearDown(() => bridge.dispose());

    test('내 정보를 받기 전(email 없음)에는 검증된 세션이 없다', () {
      expect(bridge.guard.accountId, isNull);
      signals.change(version: 1); // 로그인 시작
      expect(bridge.guard.accountId, isNull);
    });

    test('검증된 email이 생기면 그 계정의 새 세션이 시작된다', () {
      signals.change(version: 1);
      final before = bridge.guard.generation;
      signals.change(email: 'a@umc.com');
      expect(bridge.guard.accountId, 'a@umc.com');
      expect(bridge.guard.generation, greaterThan(before));
    });

    test('값이 그대로인 알림(닉네임 수정·안내 문구)에서는 번호가 바뀌지 않는다', () {
      signals.change(version: 1, email: 'a@umc.com');
      final generation = bridge.guard.generation;
      signals.change(); // 닉네임만 바뀌고 version·email은 그대로
      signals.change();
      expect(bridge.guard.generation, generation);
      expect(bridge.guard.accountId, 'a@umc.com');
    });

    test('같은 이메일로 다시 로그인(sessionVersion만 변경)해도 새 세션이다', () {
      signals.change(version: 1, email: 'a@umc.com');
      final old = bridge.guard.generation;
      // 로그아웃
      signals.change(version: 2, clearEmail: true);
      expect(bridge.guard.accountId, isNull);
      // 같은 이메일 재로그인
      signals.change(version: 3, email: 'a@umc.com');
      expect(bridge.guard.accountId, 'a@umc.com');
      expect(bridge.guard.generation, greaterThan(old));
      expect(bridge.guard.isCurrent(old, 'a@umc.com'), isFalse);
    });

    test('email이 그대로여도(중간에 비는 알림 없이) sessionVersion만 바뀌면 새 세션이다', () {
      signals.change(version: 1, email: 'a@umc.com');
      final old = bridge.guard.generation;
      signals.change(version: 2); // 같은 이메일, 번호만 올라감
      expect(bridge.guard.accountId, 'a@umc.com');
      expect(bridge.guard.generation, greaterThan(old));
      expect(bridge.guard.isCurrent(old, 'a@umc.com'), isFalse);
    });

    test('로그아웃이면 계정을 비우고 이전 세션을 무효로 한다', () {
      signals.change(version: 1, email: 'a@umc.com');
      final gen = bridge.guard.generation;
      signals.change(version: 2, clearEmail: true);
      expect(bridge.guard.accountId, isNull);
      expect(bridge.guard.isCurrent(gen, 'a@umc.com'), isFalse);
    });

    test('계정이 바뀌면(sessionVersion 변경 없이 email만 달라져도) 이전 계정의 세션은 무효다', () {
      signals.change(version: 1, email: 'a@umc.com');
      final a = bridge.guard.generation;
      signals.change(email: 'b@umc.com');
      expect(bridge.guard.accountId, 'b@umc.com');
      expect(bridge.guard.isCurrent(a, 'a@umc.com'), isFalse);
    });

    test('dispose 뒤에는 알림에 반응하지 않고 세션을 무효로 해 둔다', () {
      signals.change(version: 1, email: 'a@umc.com');
      bridge.dispose();
      expect(bridge.guard.accountId, isNull);
      final generation = bridge.guard.generation;
      signals.change(version: 2, email: 'b@umc.com');
      expect(bridge.guard.generation, generation);
      expect(bridge.guard.accountId, isNull);
      bridge.dispose(); // 두 번 불러도 괜찮다
    });

    test('실제 AuthViewModel과 이어 보면: 로그인·로그아웃·재로그인마다 번호가 달라진다', () async {
      final authApi = FakeAuthApiService();
      final memberApi = FakeMemberApiService();
      final auth = AuthViewModel(authApi, memberApi, FakeTokenStorage());
      final real = AuthSessionBridge(
        authSignals: auth,
        sessionVersion: () => auth.sessionVersion,
        verifiedEmail: () =>
            auth.status == AuthStatus.signedIn ? auth.member?.email : null,
      );
      addTearDown(() {
        real.dispose();
        auth.dispose();
      });

      await auth.login('kevin@umc.com', 'Password1234!');
      // 로그인만으로는 검증된 세션이 아니다(내 정보를 받아야 한다).
      expect(real.guard.accountId, isNull);
      await auth.loadMember();
      final first = real.guard.generation;
      expect(real.guard.accountId, 'kevin@umc.com');

      await auth.logout();
      expect(real.guard.accountId, isNull);
      expect(real.guard.isCurrent(first, 'kevin@umc.com'), isFalse);

      await auth.login('kevin@umc.com', 'Password1234!');
      await auth.loadMember();
      expect(real.guard.accountId, 'kevin@umc.com');
      expect(real.guard.generation, greaterThan(first));
      expect(real.guard.isCurrent(first, 'kevin@umc.com'), isFalse);
    });
  });

  group('SafeNotify', () {
    test('dispose 뒤에는 notifyIfAlive가 알림을 보내지 않고 예외도 없다', () {
      final notifier = _Notifier();
      var count = 0;
      notifier.addListener(() => count++);
      notifier.notifyIfAlive();
      expect(count, 1);
      expect(notifier.isDisposed, isFalse);
      notifier.dispose();
      expect(notifier.isDisposed, isTrue);
      notifier.notifyIfAlive(); // 오류 없이 조용히 무시
      expect(count, 1);
    });
  });

  group('mapBounded', () {
    test('결과를 입력과 같은 순서로 돌려준다(끝나는 순서와 무관)', () async {
      final result = await mapBounded<int, int>([1, 2, 3, 4], 2, (value) async {
        // 앞쪽이 더 늦게 끝나도 순서가 바뀌지 않는다.
        await Future<void>.delayed(Duration(milliseconds: (5 - value) * 10));
        return value * 10;
      });
      expect(result, [10, 20, 30, 40]);
    });

    test('동시에 실행하는 개수가 한도를 넘지 않는다(5개)', () async {
      var running = 0;
      var maxRunning = 0;
      final gates = <Completer<void>>[];
      final future = mapBounded<int, int>(List.generate(12, (i) => i), 5, (
        value,
      ) async {
        running++;
        if (running > maxRunning) maxRunning = running;
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
        running--;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      expect(running, 5, reason: '한꺼번에 12개가 아니라 5개만 시작한다');
      // 하나씩 끝낼 때마다 다음 작업이 한 개씩 시작된다.
      var released = 0;
      while (released < gates.length) {
        gates[released++].complete();
        await Future<void>.delayed(Duration.zero);
        expect(running, lessThanOrEqualTo(5));
      }
      expect(await future, List.generate(12, (i) => i));
      expect(maxRunning, 5);
    });

    test('입력이 한도보다 적으면 그만큼만 동시에 실행한다', () async {
      var maxRunning = 0;
      var running = 0;
      await mapBounded<int, void>([1, 2], 5, (value) async {
        running++;
        if (running > maxRunning) maxRunning = running;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        running--;
      });
      expect(maxRunning, 2);
    });

    test('빈 입력은 빈 목록을 바로 돌려주고, 한도가 0 이하면 예외다', () async {
      expect(await mapBounded<int, int>([], 5, (v) async => v), isEmpty);
      await expectLater(
        mapBounded<int, int>([1], 0, (v) async => v),
        throwsArgumentError,
      );
    });

    test('convert가 던진 예외는 그대로 전파된다(항목별 실패 처리는 호출하는 쪽 몫)', () async {
      await expectLater(
        mapBounded<int, int>([1, 2, 3], 2, (v) async {
          if (v == 2) throw StateError('2번 실패');
          return v;
        }),
        throwsA(isA<StateError>()),
      );
    });
  });
}
