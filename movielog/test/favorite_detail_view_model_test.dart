import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/session/auth_session_bridge.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/favorite_detail_view_model.dart';

import 'support.dart';

/// 상세 화면의 즐겨찾기 상태 ViewModel. 로그인·세션 판정은 진짜 AuthViewModel·AuthSessionBridge를 쓰고
/// 즐겨찾기 API만 가짜(서버 계약을 따르는 FakeFavoriteApiService)로 바꾼다.
void main() {
  late FakeFavoriteApiService api;
  late FakeAuthApiService authApi;
  late FakeMemberApiService memberApi;
  late FakeTokenStorage storage;
  late AuthViewModel auth;
  late AuthSessionBridge bridge;
  final vms = <FavoriteDetailViewModel>[];

  const movieId = 550;

  FavoriteDetailViewModel makeVm({int id = movieId, String? account}) {
    final vm = FavoriteDetailViewModel(
      movieId: id,
      favoriteApi: api,
      auth: auth,
      sessionGuard: bridge.guard,
      accountId: account ?? auth.member!.email,
    );
    vms.add(vm);
    return vm;
  }

  Future<void> signIn(String email) async {
    memberApi.member = testMember(email: email);
    authApi.accounts[email] = 'Password1234!';
    await auth.login(email, 'Password1234!');
    await auth.loadMember();
  }

  setUp(() async {
    authApi = FakeAuthApiService();
    memberApi = FakeMemberApiService();
    storage = FakeTokenStorage();
    auth = AuthViewModel(authApi, memberApi, storage);
    bridge = AuthSessionBridge(
      authSignals: auth,
      sessionVersion: () => auth.sessionVersion,
      verifiedEmail: () =>
          auth.status == AuthStatus.signedIn ? auth.member?.email : null,
    );
    api = FakeFavoriteApiService(accountOf: () => memberApi.member.email)
      ..delay = Duration.zero;
    await signIn('kevin@umc.com');
  });

  tearDown(() {
    for (final vm in vms) {
      if (!vm.isDisposed) vm.dispose();
    }
    vms.clear();
    bridge.dispose();
    auth.dispose();
  });

  group('첫 조회(load)', () {
    test('서버의 현재 여부를 받아 반영하고, 받는 동안은 isLoading이다', () async {
      api.seed([movieId]);
      api.gates['check'] = Completer<void>();
      final vm = makeVm();
      final loading = vm.load();
      expect(vm.isLoading, isTrue);
      expect(vm.hasLoadedStatus, isFalse);
      api.gates['check']!.complete();
      await loading;
      expect(vm.isLoading, isFalse);
      expect(vm.hasLoadedStatus, isTrue);
      expect(vm.isFavorite, isTrue);
      expect(api.checkCalls, [movieId]);
    });

    test('즐겨찾기하지 않은 영화는 false로 시작한다', () async {
      final vm = makeVm();
      await vm.load();
      expect(vm.isFavorite, isFalse);
      expect(vm.hasLoadedStatus, isTrue);
    });

    test('받는 중에 load를 또 불러도 요청은 한 번이다', () async {
      api.gates['check'] = Completer<void>();
      final vm = makeVm();
      final first = vm.load();
      final second = vm.load();
      api.gates['check']!.complete();
      await Future.wait([first, second]);
      expect(api.checkCalls, hasLength(1));
    });

    test('조회에 실패하면 여부를 모르는 상태로 남고, 이때 눌러도 등록·해제하지 않는다', () async {
      api.failures['check'] = networkFailure('/favorites/550');
      final vm = makeVm();
      await vm.load();
      expect(vm.hasLoadedStatus, isFalse);
      expect(vm.errorMessage, isNotNull);
      expect(await vm.toggle(), FavoriteToggleResult.ignored);
      expect(api.addCalls, isEmpty);
      expect(api.deleteCalls, isEmpty);

      api.failures.clear();
      await vm.load();
      expect(vm.hasLoadedStatus, isTrue);
      expect(vm.errorMessage, isNull);
    });

    test('아직 load하지 않았으면 toggle은 아무것도 하지 않는다', () async {
      final vm = makeVm();
      expect(await vm.toggle(), FavoriteToggleResult.ignored);
      expect(api.addCalls, isEmpty);
    });
  });

  group('등록·해제: 서버가 성공을 알려 준 뒤에만 바뀐다(optimistic 금지)', () {
    test('등록: 응답을 기다리는 동안 isFavorite은 그대로 false이고, 성공하면 true가 된다', () async {
      final vm = makeVm();
      await vm.load();
      api.gates['add'] = Completer<void>();
      final result = vm.toggle();
      expect(vm.isSaving, isTrue);
      expect(vm.isFavorite, isFalse, reason: '서버 성공 전에는 바뀌지 않는다');
      api.gates['add']!.complete();
      expect(await result, FavoriteToggleResult.added);
      expect(vm.isSaving, isFalse);
      expect(vm.isFavorite, isTrue);
      expect(api.isFavoriteOf(movieId), isTrue);
    });

    test('해제: 응답을 기다리는 동안 isFavorite은 그대로 true이고, 성공하면 false가 된다', () async {
      api.seed([movieId]);
      final vm = makeVm();
      await vm.load();
      api.gates['delete'] = Completer<void>();
      final result = vm.toggle();
      expect(vm.isSaving, isTrue);
      expect(vm.isFavorite, isTrue);
      api.gates['delete']!.complete();
      expect(await result, FavoriteToggleResult.removed);
      expect(vm.isFavorite, isFalse);
      expect(api.isFavoriteOf(movieId), isFalse);
    });

    test('요청 중에 또 누르면 무시한다(요청은 한 번)', () async {
      final vm = makeVm();
      await vm.load();
      api.gates['add'] = Completer<void>();
      final first = vm.toggle();
      final second = vm.toggle();
      expect(await second, FavoriteToggleResult.ignored);
      api.gates['add']!.complete();
      await first;
      expect(api.addCalls, [movieId]);
    });

    test('실패하면 이전 상태를 유지하고 안내 문구를 남긴다(등록 실패·해제 실패)', () async {
      final vm = makeVm();
      await vm.load();
      api.failures['add'] = apiFailure(
        '/favorites',
        500,
        code: 'COMMON500',
        message: '서버 오류',
      );
      expect(await vm.toggle(), FavoriteToggleResult.failed);
      expect(vm.isFavorite, isFalse);
      expect(vm.errorMessage, contains('등록하지 못했어요'));
      expect(vm.isSaving, isFalse);

      api.failures.clear();
      api.seed([movieId]);
      await vm.load();
      api.failures['delete'] = apiFailure(
        '/favorites/550',
        500,
        code: 'COMMON500',
        message: '서버 오류',
      );
      expect(await vm.toggle(), FavoriteToggleResult.failed);
      expect(vm.isFavorite, isTrue, reason: '해제에 실패했으니 그대로 즐겨찾기다');
      expect(vm.errorMessage, contains('해제하지 못했어요'));
    });
  });

  group('409·404는 같은 요청을 반복하지 않고 서버의 현재 값으로 맞춘다', () {
    test('이미 등록돼 있어서 409(FAVORITE409_1): POST를 되풀이하지 않고 GET으로 true로 맞춘다', () async {
      final vm = makeVm();
      await vm.load(); // false로 알고 있다
      api.seed([movieId]); // 그 사이 다른 기기에서 등록됨
      final result = await vm.toggle();
      expect(result, FavoriteToggleResult.alreadyAdded);
      expect(vm.isFavorite, isTrue);
      expect(api.addCalls, [movieId], reason: 'POST는 한 번뿐');
      expect(api.checkCalls, [movieId, movieId], reason: '처음 load + 409 뒤 GET');
      expect(vm.errorMessage, isNull);
    });

    test('이미 없어서 404(FAVORITE404_1): DELETE를 되풀이하지 않고 GET으로 false로 맞춘다', () async {
      api.seed([movieId]);
      final vm = makeVm();
      await vm.load(); // true로 알고 있다
      api.favoritesOf().clear(); // 그 사이 다른 기기에서 해제됨
      final result = await vm.toggle();
      expect(result, FavoriteToggleResult.alreadyRemoved);
      expect(vm.isFavorite, isFalse);
      expect(api.deleteCalls, [movieId], reason: 'DELETE는 한 번뿐');
      expect(api.checkCalls, hasLength(2));
    });

    test('409 뒤의 확인 GET도 실패하면 이전 상태를 유지하고 실패로 알린다', () async {
      final vm = makeVm();
      await vm.load();
      api.seed([movieId]);
      api.failOnce['check'] = [networkFailure('/favorites/550')];
      expect(await vm.toggle(), FavoriteToggleResult.failed);
      expect(vm.isFavorite, isFalse);
      expect(vm.errorMessage, isNotNull);
      expect(api.addCalls, hasLength(1));
    });
  });

  group('timeout과 응답 없는 실패', () {
    test('timeout이면 같은 POST를 자동으로 다시 보내지 않는다(서버에서는 성공했을 수 있다)', () async {
      final vm = makeVm();
      await vm.load();
      api.timeoutAfterApply.add('add'); // 서버에는 저장되고 응답만 오지 않음
      final result = await vm.toggle();
      expect(result, FavoriteToggleResult.failed);
      expect(api.addCalls, [movieId], reason: '자동 재시도 없음');
      expect(vm.isFavorite, isFalse, reason: '서버 성공을 확인하지 못했으니 아이콘은 그대로');
      expect(vm.errorMessage, contains('응답이 늦어'));
      expect(vm.isSaving, isFalse);
    });

    test('timeout 뒤에 사용자가 다시 누르면 409 → GET으로 서버 값(true)에 맞춰진다', () async {
      final vm = makeVm();
      await vm.load();
      api.timeoutAfterApply.add('add');
      await vm.toggle();
      api.timeoutAfterApply.clear();
      expect(await vm.toggle(), FavoriteToggleResult.alreadyAdded);
      expect(vm.isFavorite, isTrue);
      expect(api.addCalls, hasLength(2), reason: '사용자가 직접 누른 두 번째만');
    });

    test('해제 timeout도 자동 재시도하지 않고 아이콘을 유지한다', () async {
      api.seed([movieId]);
      final vm = makeVm();
      await vm.load();
      api.timeoutAfterApply.add('delete');
      expect(await vm.toggle(), FavoriteToggleResult.failed);
      expect(api.deleteCalls, hasLength(1));
      expect(vm.isFavorite, isTrue);
    });
  });

  group('세션 만료와 로그아웃', () {
    test('AUTH401_3이면 현재 세션을 한 번 정리하고 안내 Snackbar 대신 로그인으로 보낼 상태가 된다', () async {
      final vm = makeVm();
      await vm.load();
      api.failures['add'] = apiFailure(
        '/favorites',
        401,
        code: 'AUTH401_3',
        message: '토큰 만료',
      );
      expect(await vm.toggle(), FavoriteToggleResult.ignored);
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
      expect(storage.deletes, 1);
      expect(vm.isFavorite, isFalse);
    });

    test('AUTH401_2·AUTH401_4도 만료다', () async {
      for (final code in ['AUTH401_2', 'AUTH401_4']) {
        await signIn('kevin@umc.com');
        final vm = makeVm();
        await vm.load();
        api.failures['add'] = apiFailure(
          '/favorites',
          401,
          code: code,
          message: '만료',
        );
        await vm.toggle();
        expect(auth.status, AuthStatus.signedOut, reason: code);
        api.failures.clear();
      }
    });

    test('같은 세션에서 요청 둘이 동시에 401을 받아도 정리는 한 번이다', () async {
      final a = makeVm(id: 1);
      final b = makeVm(id: 2);
      api.failures['check'] = apiFailure(
        '/favorites/1',
        401,
        code: 'AUTH401_3',
        message: '토큰 만료',
      );
      await Future.wait([a.load(), b.load()]);
      expect(auth.status, AuthStatus.signedOut);
      expect(storage.deletes, 1, reason: '저장소 정리는 한 번만');
    });

    test('load에서 받은 401도 만료로 정리한다', () async {
      final vm = makeVm();
      api.failures['check'] = apiFailure(
        '/favorites/550',
        401,
        code: 'AUTH401_2',
        message: '토큰 없음',
      );
      await vm.load();
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
    });

    test('403이나 네트워크 실패는 로그아웃하지 않는다', () async {
      final vm = makeVm();
      await vm.load();
      api.failures['add'] = apiFailure(
        '/favorites',
        403,
        code: 'COMMON403',
        message: '권한 없음',
      );
      expect(await vm.toggle(), FavoriteToggleResult.failed);
      expect(auth.status, AuthStatus.signedIn);

      api.failures['add'] = networkFailure('/favorites');
      expect(await vm.toggle(), FavoriteToggleResult.failed);
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.sessionExpired, isFalse);
      expect(storage.deletes, 0);
      expect(storage.token, isNotNull);
    });

    test('이전 로그인 세션에서 늦게 도착한 401이 새로 로그인한 계정을 로그아웃시키지 않는다', () async {
      final oldVm = makeVm();
      api.gates['check'] = Completer<void>();
      api.failOnce['check'] = [
        apiFailure('/favorites/550', 401, code: 'AUTH401_3', message: '만료'),
      ];
      final late = oldVm.load(); // 아직 응답 전

      await auth.logout();
      await signIn('sue@umc.com'); // 다른 계정으로 로그인
      expect(auth.member!.email, 'sue@umc.com');

      api.gates['check']!.complete(); // 이제서야 이전 세션의 401 도착
      await late;
      expect(auth.status, AuthStatus.signedIn, reason: '새 계정은 그대로');
      expect(auth.member!.email, 'sue@umc.com');
      expect(auth.sessionExpired, isFalse);
      expect(storage.token, isNotNull);
    });

    test('같은 이메일로 다시 로그인해도 이전 세션의 늦은 401은 새 세션에 영향이 없다', () async {
      final oldVm = makeVm();
      api.gates['check'] = Completer<void>();
      api.failOnce['check'] = [
        apiFailure('/favorites/550', 401, code: 'AUTH401_4', message: '만료'),
      ];
      final late = oldVm.load();

      await auth.logout();
      await signIn('kevin@umc.com'); // 같은 이메일, 새 세션
      api.gates['check']!.complete();
      await late;
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.sessionExpired, isFalse);
    });

    test('SessionGuard가 새 세션을 아직 모르는 틈에도, 요청을 보낸 인증 세션이 지났다면 만료 처리하지 않는다(forVersion)', () async {
      // 인증 상태와 연결되지 않은 guard: 로그인 세션이 바뀌어도 계속 "현재"라고 답한다.
      final staleGuard = SessionGuard()..startSession('kevin@umc.com');
      final vm = FavoriteDetailViewModel(
        movieId: movieId,
        favoriteApi: api,
        auth: auth,
        sessionGuard: staleGuard,
        accountId: 'kevin@umc.com',
      );
      vms.add(vm);
      api.gates['check'] = Completer<void>();
      api.failOnce['check'] = [
        apiFailure('/favorites/550', 401, code: 'AUTH401_3', message: '만료'),
      ];
      final late = vm.load();

      await auth.logout();
      await signIn('kevin@umc.com'); // 새 로그인 세션
      final deletesBefore = storage.deletes;
      api.gates['check']!.complete();
      await late;
      expect(auth.status, AuthStatus.signedIn, reason: '이전 세션의 401로 새 세션을 지우지 않는다');
      expect(auth.sessionExpired, isFalse);
      expect(storage.deletes, deletesBefore);
      expect(storage.token, isNotNull);
    });

    test('이전 세션에서 늦게 도착한 성공 응답은 화면 상태에 반영하지 않는다', () async {
      final oldVm = makeVm();
      await oldVm.load();
      api.gates['add'] = Completer<void>();
      final result = oldVm.toggle();
      await auth.logout();
      api.gates['add']!.complete();
      expect(await result, FavoriteToggleResult.ignored);
      expect(oldVm.isFavorite, isFalse, reason: '끝난 세션의 응답은 버린다');
    });

    test('로그아웃된 세션의 ViewModel은 load·toggle을 보내지 않는다', () async {
      final vm = makeVm();
      await vm.load();
      await auth.logout();
      final checksBefore = api.checkCalls.length;
      await vm.load();
      expect(await vm.toggle(), FavoriteToggleResult.ignored);
      expect(api.checkCalls, hasLength(checksBefore));
      expect(api.addCalls, isEmpty);
    });
  });

  group('dispose', () {
    test('toggle 응답이 dispose 뒤에 도착해도 무시하고 예외도 없다', () async {
      final vm = makeVm();
      await vm.load();
      api.gates['add'] = Completer<void>();
      final result = vm.toggle();
      vm.dispose();
      api.gates['add']!.complete();
      expect(await result, FavoriteToggleResult.ignored);
      expect(vm.isDisposed, isTrue);
    });

    test('load 응답이 dispose 뒤에 도착해도 무시하고 예외도 없다', () async {
      final vm = makeVm();
      api.gates['check'] = Completer<void>();
      final loading = vm.load();
      vm.dispose();
      api.gates['check']!.complete();
      await loading;
      expect(vm.hasLoadedStatus, isFalse);
    });
  });
}
