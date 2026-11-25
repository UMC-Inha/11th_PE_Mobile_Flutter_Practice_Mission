import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:movielog/core/session/auth_session_bridge.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/core/utils/map_bounded.dart';
import 'package:movielog/data/models/favorite_check_dto.dart';
import 'package:movielog/data/models/favorite_response_dto.dart';
import 'package:movielog/view_models/favorite_detail_view_model.dart';
import 'package:movielog/view_models/favorites_view_model.dart';
import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/widgets/favorite_button.dart';

import 'fakes/fake_favorite_api_service.dart';
import 'fakes/fake_tmdb_movie_service.dart';

const _account = 'a@example.com';

SessionGuard _guard([String account = _account]) =>
    SessionGuard()..startSession(account);

FavoriteDetailViewModel _detailVm(
  FakeFavoriteApiService api,
  SessionGuard guard, {
  int movieId = 550,
  Future<void> Function()? onExpired,
}) {
  return FavoriteDetailViewModel(
    movieId: movieId,
    favoriteApi: api,
    sessionGuard: guard,
    accountId: _account,
    onSessionExpired: onExpired ?? () async {},
  );
}

void main() {
  group('DTO', () {
    test('여부 조회 응답에는 movieId가 없어 요청한 movieId를 함께 넘긴다', () {
      final dto = FavoriteCheckDto.fromJson({'isFavorite': true}, movieId: 550);
      expect(dto.movieId, 550);
      expect(dto.isFavorite, isTrue);
    });

    test('즐겨찾기 응답을 파싱한다', () {
      final dto = FavoriteResponseDto.fromJson({
        'favoriteId': 3,
        'movieId': 550,
        'createdAt': '2026-09-06T12:14:03.000Z',
      });
      expect(dto.favoriteId, 3);
      expect(dto.movieId, 550);
    });
  });

  group('mapBounded', () {
    test('동시에 최대 N개만 실행하고 결과는 입력 순서를 유지한다', () async {
      var running = 0;
      var maxRunning = 0;
      final result = await mapBounded(List.generate(12, (i) => i), 5, (
        value,
      ) async {
        running++;
        if (running > maxRunning) maxRunning = running;
        await Future<void>.delayed(Duration(milliseconds: 12 - value));
        running--;
        return value * 10;
      });
      expect(maxRunning, 5);
      expect(result, List.generate(12, (i) => i * 10));
    });
  });

  group('SessionGuard / AuthSessionBridge', () {
    test('같은 이메일로 다시 로그인해도 새 세션이다', () {
      final auth = ValueNotifier<int>(1);
      String? email = _account;
      final bridge = AuthSessionBridge(
        authSignals: auth,
        sessionVersion: () => auth.value,
        verifiedEmail: () => email,
      );
      final first = bridge.guard.generation;
      expect(bridge.guard.isCurrent(first, _account), isTrue);

      // 로그아웃 → 같은 계정으로 다시 로그인
      email = null;
      auth.value = 2;
      expect(bridge.guard.accountId, isNull);
      email = _account;
      auth.value = 3;
      expect(bridge.guard.isCurrent(first, _account), isFalse);
      expect(bridge.guard.accountId, _account);
      bridge.dispose();
    });
  });

  group('FavoriteDetailViewModel', () {
    test('load는 서버의 즐겨찾기 여부를 반영한다', () async {
      final api = FakeFavoriteApiService(initial: {550});
      final vm = _detailVm(api, _guard());
      await vm.load();
      expect(vm.hasLoadedStatus, isTrue);
      expect(vm.isFavorite, isTrue);
    });

    test('등록·해제는 서버 성공 후에만 북마크를 바꾼다', () async {
      final api = FakeFavoriteApiService();
      final vm = _detailVm(api, _guard());
      await vm.load();

      final adding = vm.toggle();
      expect(vm.isSaving, isTrue);
      expect(vm.isFavorite, isFalse); // optimistic update 하지 않음
      expect(await adding, '즐겨찾기에 추가했습니다.');
      expect(vm.isFavorite, isTrue);

      expect(await vm.toggle(), '즐겨찾기에서 삭제했습니다.');
      expect(vm.isFavorite, isFalse);
      expect(api.favorites, isEmpty);
    });

    test('실패하면 이전 상태를 유지하고 실패 문구를 돌려준다', () async {
      final api = FakeFavoriteApiService();
      final vm = _detailVm(api, _guard());
      await vm.load();
      api.nextNetworkError = true;
      expect(await vm.toggle(), '즐겨찾기 등록에 실패했습니다.');
      expect(vm.isFavorite, isFalse);
      expect(vm.isSaving, isFalse);
    });

    test('FAVORITE409_1이면 POST를 반복하지 않고 GET으로 상태를 맞춘다', () async {
      final api = FakeFavoriteApiService();
      final vm = _detailVm(api, _guard());
      await vm.load();
      api
        ..applyBeforeError = true
        ..nextErrorCode = 'FAVORITE409_1'
        ..nextErrorStatus = 409;
      await vm.toggle();
      expect(vm.isFavorite, isTrue);
      expect(vm.errorMessage, isNull);
      expect(api.requests.where((r) => r.startsWith('POST')), hasLength(1));
      expect(api.requests.last, 'GET /v8/favorites/550');
    });

    test('FAVORITE404_1이면 현재 여부를 다시 조회한다', () async {
      final api = FakeFavoriteApiService(initial: {550});
      final vm = _detailVm(api, _guard());
      await vm.load();
      api
        ..applyBeforeError = true
        ..nextErrorCode = 'FAVORITE404_1'
        ..nextErrorStatus = 404;
      await vm.toggle();
      expect(vm.isFavorite, isFalse);
      expect(api.requests.last, 'GET /v8/favorites/550');
    });

    test('만료 토큰(AUTH401_4)은 현재 세션일 때만 한 번 정리한다', () async {
      final api = FakeFavoriteApiService();
      var expired = 0;
      final vm = _detailVm(api, _guard(), onExpired: () async => expired++);
      await vm.load();
      api
        ..nextErrorCode = 'AUTH401_4'
        ..nextErrorStatus = 401;
      await vm.toggle();
      expect(expired, 1);
    });

    test('403이나 네트워크 실패는 세션을 정리하지 않는다', () async {
      final api = FakeFavoriteApiService();
      var expired = 0;
      final vm = _detailVm(api, _guard(), onExpired: () async => expired++);
      await vm.load();
      api
        ..nextErrorCode = 'COMMON403'
        ..nextErrorStatus = 403;
      await vm.toggle();
      api.nextNetworkError = true;
      await vm.toggle();
      expect(expired, 0);
    });

    test('세션이 바뀐 뒤 도착한 401은 현재 계정을 로그아웃시키지 않는다', () async {
      final api = FakeFavoriteApiService();
      final guard = _guard();
      var expired = 0;
      final vm = _detailVm(api, guard, onExpired: () async => expired++);
      await vm.load();
      api
        ..nextErrorCode = 'AUTH401_3'
        ..nextErrorStatus = 401;
      final pending = vm.toggle();
      guard
        ..invalidate()
        ..startSession('b@example.com'); // 계정 B로 전환
      expect(await pending, isNull);
      expect(expired, 0);
    });
  });

  group('FavoritesViewModel', () {
    FavoritesViewModel listVm(
      FakeFavoriteApiService api,
      FakeTmdbMovieService tmdb,
      SessionGuard guard,
    ) {
      return FavoritesViewModel(
        favoriteApi: api,
        tmdbApi: tmdb,
        sessionGuard: guard,
        accountId: _account,
        onSessionExpired: () async {},
      );
    }

    test('즐겨찾기 movieId로 TMDB 영화 정보를 합친다', () async {
      final vm = listVm(
        FakeFavoriteApiService(initial: {1, 2}),
        FakeTmdbMovieService(),
        _guard(),
      );
      await vm.refresh();
      expect(vm.phase, LoadPhase.ready);
      expect(vm.items.map((item) => item.movie?.title), ['영화 1', '영화 2']);
    });

    test('빈 목록과 조회 오류를 구분한다', () async {
      final empty = listVm(
        FakeFavoriteApiService(),
        FakeTmdbMovieService(),
        _guard(),
      );
      await empty.refresh();
      expect(empty.phase, LoadPhase.empty);

      final failing = FakeFavoriteApiService()..nextNetworkError = true;
      final error = listVm(failing, FakeTmdbMovieService(), _guard());
      await error.refresh();
      expect(error.phase, LoadPhase.error);
      expect(error.errorMessage, isNotNull);
    });

    test('영화 한 건 조회 실패가 목록 전체를 비우지 않고 그 카드만 다시 조회한다', () async {
      final tmdb = FakeTmdbMovieService(networkFailMovieIds: {2});
      final vm = listVm(
        FakeFavoriteApiService(initial: {1, 2, 3}),
        tmdb,
        _guard(),
      );
      await vm.refresh();
      expect(vm.phase, LoadPhase.ready);
      expect(vm.items.map((item) => item.hasMovie), [true, false, true]);

      tmdb.networkFailMovieIds.clear();
      tmdb.detailRequests.clear();
      await vm.retryMovie(2);
      expect(vm.items.every((item) => item.hasMovie), isTrue);
      expect(tmdb.detailRequests, [2]);
    });

    test('상세에서 해제한 뒤 refresh하면 목록에서 사라진다', () async {
      final api = FakeFavoriteApiService(initial: {1, 2});
      final vm = listVm(api, FakeTmdbMovieService(), _guard());
      await vm.refresh();
      api.favorites.remove(1);
      await vm.refresh();
      expect(vm.items.map((item) => item.favorite.movieId), [2]);
    });

    test('계정이 바뀐 뒤 도착한 응답은 반영하지 않는다', () async {
      final guard = _guard();
      final vm = listVm(
        FakeFavoriteApiService(initial: {1}),
        FakeTmdbMovieService(),
        guard,
      );
      final pending = vm.refresh();
      guard
        ..invalidate()
        ..startSession('b@example.com');
      await pending;
      expect(vm.items, isEmpty);
    });
  });

  testWidgets('북마크를 누르면 등록 후 아이콘이 바뀌고 Snackbar를 보여준다', (tester) async {
    final api = FakeFavoriteApiService();
    final vm = _detailVm(api, _guard());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider.value(
            value: vm,
            child: const FavoriteButton(),
          ),
        ),
      ),
    );
    await tester.runAsync(vm.load);
    await tester.pump();
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.text('즐겨찾기에 추가했습니다.'), findsOneWidget);
  });

  test('보호 요청 판정에 사용한 DioException code 추출', () {
    final options = RequestOptions(path: '/v8/favorites');
    final error = DioException(
      requestOptions: options,
      response: Response(
        requestOptions: options,
        statusCode: 401,
        data: {'code': 'AUTH401_1'},
      ),
    );
    // 로그인 실패(AUTH401_1)는 세션 만료가 아닙니다.
    expect(isSessionExpiredError(error), isFalse);
  });
}
