import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/session/auth_session_bridge.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/favorites_view_model.dart';
import 'package:movielog/view_models/load_phase.dart';

import 'support.dart';

/// "내 즐겨찾기" ViewModel. 즐겨찾기 목록(MovieLog) → 영화 정보 보충(TMDB) 순서와
/// 한 건 실패·세션 전환 규칙을 확인한다.
void main() {
  late FakeFavoriteApiService api;
  late FakeTmdbMovieService tmdb;
  late FakeAuthApiService authApi;
  late FakeMemberApiService memberApi;
  late FakeTokenStorage storage;
  late AuthViewModel auth;
  late AuthSessionBridge bridge;
  final vms = <FavoritesViewModel>[];

  FavoritesViewModel makeVm({int concurrency = 5}) {
    final vm = FavoritesViewModel(
      favoriteApi: api,
      tmdbApi: tmdb,
      auth: auth,
      sessionGuard: bridge.guard,
      accountId: auth.member!.email,
      enrichmentConcurrency: concurrency,
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

  void knowMovies(Iterable<int> ids) {
    for (final id in ids) {
      tmdb.moviesById[id] = movie(id, title: '영화 제목 $id');
    }
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
    tmdb = FakeTmdbMovieService(delay: Duration.zero);
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

  group('refresh: 목록 → 영화 정보 보충 → 상태', () {
    test('즐겨찾기를 최신 등록순으로 받아 TMDB 영화 정보를 붙인다', () async {
      api.seed([550, 603, 27205]); // 마지막이 가장 최신
      knowMovies([550, 603, 27205]);
      final vm = makeVm();
      expect(vm.phase, LoadPhase.idle);
      final loading = vm.refresh();
      expect(vm.phase, LoadPhase.loading);
      await loading;
      expect(vm.phase, LoadPhase.ready);
      expect(vm.items.map((i) => i.favorite.movieId), [27205, 603, 550]);
      expect(vm.items.map((i) => i.movie?.title), [
        '영화 제목 27205',
        '영화 제목 603',
        '영화 제목 550',
      ]);
      expect(api.listCalls, 1);
    });

    test('즐겨찾기가 없으면 empty이고 TMDB는 부르지 않는다', () async {
      final vm = makeVm();
      await vm.refresh();
      expect(vm.phase, LoadPhase.empty);
      expect(vm.items, isEmpty);
      expect(tmdb.movieCalls, isEmpty);
      expect(vm.errorMessage, isNull);
    });

    test('목록 조회가 실패하면 error이고, 다시 시도(refresh)하면 복구된다', () async {
      api.seed([550]);
      knowMovies([550]);
      api.failures['list'] = networkFailure('/favorites');
      final vm = makeVm();
      await vm.refresh();
      expect(vm.phase, LoadPhase.error);
      expect(vm.errorMessage, contains('네트워크'));
      expect(vm.items, isEmpty);
      expect(auth.status, AuthStatus.signedIn, reason: '네트워크 실패는 로그아웃 사유가 아니다');

      api.failures.clear();
      await vm.refresh();
      expect(vm.phase, LoadPhase.ready);
      expect(vm.items, hasLength(1));
      expect(vm.errorMessage, isNull);
    });

    test('서버 오류 응답(500)도 error이고 로그아웃하지 않는다', () async {
      api.failures['list'] = apiFailure(
        '/favorites',
        500,
        code: 'COMMON500',
        message: '서버 오류',
      );
      final vm = makeVm();
      await vm.refresh();
      expect(vm.phase, LoadPhase.error);
      expect(auth.status, AuthStatus.signedIn);
    });

    test('영화 정보 한 건만 실패해도 목록 전체는 ready이고 그 카드만 placeholder다', () async {
      api.seed([550, 603, 27205]);
      knowMovies([550, 27205]); // 603은 TMDB 조회 실패
      tmdb.failMovieIds.add(603);
      final vm = makeVm();
      await vm.refresh();
      expect(vm.phase, LoadPhase.ready, reason: '1건 실패가 전체 실패가 아니다');
      expect(vm.items, hasLength(3));
      final byId = {for (final i in vm.items) i.favorite.movieId: i};
      expect(byId[550]!.movie, isNotNull);
      expect(byId[27205]!.movie, isNotNull);
      expect(byId[603]!.movie, isNull);
      expect(byId[603]!.errorMessage, isNotNull);
      expect(byId[603]!.hasMovie, isFalse);
    });

    test('모든 영화 정보가 실패해도 즐겨찾기 목록은 사라지지 않는다', () async {
      api.seed([550, 603]);
      // TMDB는 어떤 영화도 모른다.
      final vm = makeVm();
      await vm.refresh();
      expect(vm.phase, LoadPhase.ready);
      expect(vm.items, hasLength(2));
      expect(vm.items.every((i) => i.movie == null), isTrue);
    });

    test('실패한 카드 한 장만 retryMovie로 다시 조회하고 나머지 카드는 그대로다', () async {
      api.seed([550, 603, 27205]);
      knowMovies([550, 603, 27205]);
      tmdb.failMovieIds.add(603);
      final vm = makeVm();
      await vm.refresh();
      final before = {for (final i in vm.items) i.favorite.movieId: i};
      expect(before[603]!.movie, isNull);
      final callsBefore = tmdb.movieCalls.length;

      tmdb.failMovieIds.clear();
      await vm.retryMovie(603);
      expect(tmdb.movieCalls.length - callsBefore, 1, reason: '그 영화 한 건만 다시 조회');
      expect(tmdb.movieCalls.last, 603);
      final after = {for (final i in vm.items) i.favorite.movieId: i};
      expect(after[603]!.movie?.title, '영화 제목 603');
      expect(identical(after[550], before[550]), isTrue);
      expect(identical(after[27205], before[27205]), isTrue);
      expect(vm.retryingMovieIds, isEmpty);
      expect(api.listCalls, 1, reason: '목록 전체를 다시 받지 않는다');
    });

    test('다시 조회도 실패하면 placeholder로 남고, 조회 중에는 retryingMovieIds에 들어 있다', () async {
      api.seed([603]);
      tmdb.failMovieIds.add(603);
      knowMovies([603]);
      final vm = makeVm();
      await vm.refresh();
      tmdb.gate = Completer<void>();
      final retrying = vm.retryMovie(603);
      expect(vm.retryingMovieIds, {603});
      // 같은 카드를 또 눌러도 요청은 늘지 않는다.
      final callsDuring = tmdb.movieCalls.length;
      await vm.retryMovie(603);
      expect(tmdb.movieCalls.length, callsDuring);
      tmdb.gate!.complete();
      await retrying;
      expect(vm.retryingMovieIds, isEmpty);
      expect(vm.items.single.movie, isNull);
      expect(vm.items.single.errorMessage, isNotNull);
    });

    test('영화 정보 요청은 한 번에 최대 5개만 동시에 나간다', () async {
      api.seed(List.generate(12, (i) => 1000 + i));
      knowMovies(List.generate(12, (i) => 1000 + i));
      tmdb.delay = const Duration(milliseconds: 20);
      final vm = makeVm();
      await vm.refresh();
      expect(vm.items, hasLength(12));
      expect(tmdb.maxConcurrentMovieCalls, 5);
      expect(tmdb.movieCalls, hasLength(12));
    });

    test('같은 refresh를 두 번 시작하면 나중에 시작한 결과만 반영한다', () async {
      api.seed([550]);
      knowMovies([550, 603]);
      api.delay = const Duration(milliseconds: 60);
      final vm = makeVm();
      final first = vm.refresh(); // 느린 첫 요청: 응답 시점에 서버 목록을 읽는다
      await Future<void>.delayed(const Duration(milliseconds: 5));
      api.delay = Duration.zero;
      final second = vm.refresh();
      await second;
      expect(vm.items.map((i) => i.favorite.movieId), [550]);
      api.seed([603]); // 첫 요청이 아직 안 끝난 사이에 서버가 바뀜
      await first;
      expect(
        vm.items.map((i) => i.favorite.movieId),
        [550],
        reason: '먼저 시작한 refresh의 늦은 응답이 나중 결과를 덮지 않는다',
      );
    });
  });

  group('세션', () {
    test('로그아웃한 뒤 도착한 응답은 반영하지 않는다(이전 계정 목록이 남지 않는다)', () async {
      api.seed([550]);
      knowMovies([550]);
      api.gates['list'] = Completer<void>();
      final vm = makeVm();
      final loading = vm.refresh();
      await auth.logout();
      api.gates['list']!.complete();
      await loading;
      expect(vm.items, isEmpty);
      expect(vm.phase, isNot(LoadPhase.ready));
    });

    test('계정 전환(A → B) 뒤에 도착한 A의 응답은 B 화면에 섞이지 않는다', () async {
      api.seed([550], account: 'kevin@umc.com');
      api.seed([603], account: 'sue@umc.com');
      knowMovies([550, 603]);
      api.gates['list'] = Completer<void>();
      final vmOfA = makeVm();
      final loadingA = vmOfA.refresh();

      await auth.logout();
      await signIn('sue@umc.com');
      api.gates['list']!.complete();
      await loadingA;
      expect(vmOfA.items, isEmpty, reason: 'A의 ViewModel에는 아무것도 반영되지 않는다');

      final vmOfB = makeVm();
      await vmOfB.refresh();
      expect(vmOfB.items.map((i) => i.favorite.movieId), [603]);
    });

    test('같은 이메일로 다시 로그인해도 이전 세션의 늦은 응답은 버린다', () async {
      api.seed([550]);
      knowMovies([550]);
      api.gates['list'] = Completer<void>();
      final vm = makeVm();
      final loading = vm.refresh();
      await auth.logout();
      await signIn('kevin@umc.com');
      api.gates['list']!.complete();
      await loading;
      expect(vm.items, isEmpty);
    });

    test('영화 정보를 받는 중에 로그아웃해도 그 결과는 반영하지 않는다', () async {
      api.seed([550]);
      knowMovies([550]);
      tmdb.gate = Completer<void>();
      final vm = makeVm();
      final loading = vm.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await auth.logout();
      tmdb.gate!.complete();
      await loading;
      expect(vm.items, isEmpty);
    });

    test('토큰 만료(AUTH401_3)는 세션을 한 번 정리한다(error 화면이 아니다)', () async {
      api.failures['list'] = apiFailure(
        '/favorites',
        401,
        code: 'AUTH401_3',
        message: '토큰 만료',
      );
      final vm = makeVm();
      await vm.refresh();
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
      expect(storage.deletes, 1);
      expect(vm.phase, isNot(LoadPhase.error));
    });

    test('SessionGuard가 새 세션을 아직 모르는 틈에도, 이전 인증 세션의 늦은 401로 새 세션을 지우지 않는다(forVersion)', () async {
      final staleGuard = SessionGuard()..startSession('kevin@umc.com');
      final vm = FavoritesViewModel(
        favoriteApi: api,
        tmdbApi: tmdb,
        auth: auth,
        sessionGuard: staleGuard,
        accountId: 'kevin@umc.com',
      );
      vms.add(vm);
      api.gates['list'] = Completer<void>();
      api.failOnce['list'] = [
        apiFailure('/favorites', 401, code: 'AUTH401_3', message: '만료'),
      ];
      final loading = vm.refresh();

      await auth.logout();
      await signIn('kevin@umc.com');
      final deletesBefore = storage.deletes;
      api.gates['list']!.complete();
      await loading;
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.sessionExpired, isFalse);
      expect(storage.deletes, deletesBefore);
    });

    test('403은 로그아웃하지 않고 error로 보여 준다', () async {
      api.failures['list'] = apiFailure(
        '/favorites',
        403,
        code: 'COMMON403',
        message: '권한 없음',
      );
      final vm = makeVm();
      await vm.refresh();
      expect(vm.phase, LoadPhase.error);
      expect(auth.status, AuthStatus.signedIn);
      expect(storage.deletes, 0);
    });

    test('로그아웃된 세션의 ViewModel은 refresh해도 요청하지 않는다', () async {
      final vm = makeVm();
      await auth.logout();
      await vm.refresh();
      expect(api.listCalls, 0);
      expect(vm.phase, LoadPhase.idle);
    });

    test('dispose 뒤에 도착한 응답은 무시하고 예외도 없다', () async {
      api.seed([550]);
      knowMovies([550]);
      api.gates['list'] = Completer<void>();
      final vm = makeVm();
      final loading = vm.refresh();
      vm.dispose();
      api.gates['list']!.complete();
      await loading;
      expect(vm.items, isEmpty);
    });
  });
}
