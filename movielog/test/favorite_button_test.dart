import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/features/auth/presentation/login_screen.dart';
import 'package:movielog/features/movies/presentation/movie_detail_screen.dart';
import 'package:movielog/features/movies/presentation/widgets/favorite_button.dart';

import 'support.dart';

/// 영화 상세의 즐겨찾기 버튼(앱 전체를 가짜 서버로 조립해서 확인한다).
void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1170, 2532);
    view.devicePixelRatio = 3;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  late AppHarness h;
  const movieId = 550;

  setUp(() {
    h = AppHarness();
    h.tmdb.moviesById[movieId] = movie(movieId, title: '파이트 클럽');
  });

  Future<void> openDetail(WidgetTester tester) async {
    await tester.pumpWidget(h.app(initialLocation: AppRoutes.movieDetail(movieId)));
    await settle(tester);
    expect(find.text('파이트 클럽'), findsOneWidget);
  }

  bool buttonEnabled(WidgetTester tester) =>
      tester.widget<IconButton>(find.byKey(favoriteButtonKey)).onPressed != null;

  Finder filledBookmark() => find.byIcon(Icons.bookmark);
  Finder emptyBookmark() => find.byIcon(Icons.bookmark_border);

  group('첫 조회', () {
    testWidgets('상세에 들어오면 서버의 즐겨찾기 여부를 한 번 조회해 북마크에 반영한다', (tester) async {
      h.favoriteApi.seed([movieId]);
      await openDetail(tester);
      expect(h.favoriteApi.checkCalls, [movieId]);
      expect(filledBookmark(), findsOneWidget);
      expect(emptyBookmark(), findsNothing);
      expect(
        tester.widget<IconButton>(find.byKey(favoriteButtonKey)).tooltip,
        '즐겨찾기 해제',
      );
      // 화면이 다시 그려져도 조회는 늘지 않는다(build에서 조회하지 않는다).
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(h.favoriteApi.checkCalls, hasLength(1));
    });

    testWidgets('즐겨찾기하지 않은 영화는 빈 북마크이고 눌러서 등록할 수 있다', (tester) async {
      await openDetail(tester);
      expect(emptyBookmark(), findsOneWidget);
      expect(buttonEnabled(tester), isTrue);
    });

    testWidgets('여부를 받는 동안에는 버튼이 비활성이고 북마크 자리에 로딩만 보인다', (tester) async {
      h.favoriteApi.gates['check'] = Completer<void>();
      await tester.pumpWidget(
        h.app(initialLocation: AppRoutes.movieDetail(movieId)),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(favoriteProgressKey), findsOneWidget);
      expect(buttonEnabled(tester), isFalse);
      expect(filledBookmark(), findsNothing);
      expect(emptyBookmark(), findsNothing);

      h.favoriteApi.gates['check']!.complete();
      await settle(tester);
      expect(find.byKey(favoriteProgressKey), findsNothing);
      expect(emptyBookmark(), findsOneWidget);
      expect(buttonEnabled(tester), isTrue);
    });

    testWidgets('첫 조회에 실패하면 새로고침 버튼이 보이고, 누르면 다시 조회해 북마크로 바뀐다', (tester) async {
      h.favoriteApi.failures['check'] = networkFailure('/favorites/550');
      await openDetail(tester);
      expect(find.byKey(favoriteReloadKey), findsOneWidget);
      expect(find.byKey(favoriteButtonKey), findsNothing);
      // 여부를 모르는 채로 등록·해제 요청을 보내지 않는다.
      expect(h.favoriteApi.addCalls, isEmpty);

      h.favoriteApi.failures.clear();
      await tester.tap(find.byKey(favoriteReloadKey));
      await settle(tester);
      expect(find.byKey(favoriteReloadKey), findsNothing);
      expect(find.byKey(favoriteButtonKey), findsOneWidget);
      expect(emptyBookmark(), findsOneWidget);
    });
  });

  group('등록·해제', () {
    testWidgets('등록: 요청 중에는 버튼이 비활성이고 아이콘은 서버 응답 전까지 바뀌지 않는다', (tester) async {
      await openDetail(tester);
      h.favoriteApi.gates['add'] = Completer<void>();
      await tester.tap(find.byKey(favoriteButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(favoriteProgressKey), findsOneWidget);
      expect(buttonEnabled(tester), isFalse);
      expect(filledBookmark(), findsNothing, reason: '서버 성공 전에는 채워지지 않는다(optimistic 금지)');
      // 요청 중에 또 눌러도 요청은 한 번이다.
      await tester.tap(find.byKey(favoriteButtonKey), warnIfMissed: false);
      await tester.pump();
      expect(h.favoriteApi.addCalls, [movieId]);

      h.favoriteApi.gates['add']!.complete();
      await settle(tester);
      expect(find.byKey(favoriteProgressKey), findsNothing);
      expect(filledBookmark(), findsOneWidget);
      expect(find.text('즐겨찾기에 추가했어요.'), findsOneWidget);
      expect(h.favoriteApi.isFavoriteOf(movieId), isTrue);
    });

    testWidgets('해제: 서버가 해제를 확인한 뒤에 빈 북마크가 된다', (tester) async {
      h.favoriteApi.seed([movieId]);
      await openDetail(tester);
      h.favoriteApi.gates['delete'] = Completer<void>();
      await tester.tap(find.byKey(favoriteButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(filledBookmark(), findsNothing);
      expect(emptyBookmark(), findsNothing, reason: '요청 중에는 북마크 자리에 로딩만');
      expect(find.byKey(favoriteProgressKey), findsOneWidget);

      h.favoriteApi.gates['delete']!.complete();
      await settle(tester);
      expect(emptyBookmark(), findsOneWidget);
      expect(find.text('즐겨찾기에서 삭제했어요.'), findsOneWidget);
      expect(h.favoriteApi.isFavoriteOf(movieId), isFalse);
    });

    testWidgets('등록 실패: 이전 아이콘을 유지하고 Snackbar로 알리며 로그아웃하지 않는다', (tester) async {
      await openDetail(tester);
      h.favoriteApi.failures['add'] = apiFailure(
        '/favorites',
        500,
        code: 'COMMON500',
        message: '서버 오류',
      );
      await tester.tap(find.byKey(favoriteButtonKey));
      await settle(tester);
      expect(emptyBookmark(), findsOneWidget);
      expect(find.textContaining('즐겨찾기를 등록하지 못했어요'), findsOneWidget);
      expect(find.byType(MovieDetailScreen), findsOneWidget);
      expect(buttonEnabled(tester), isTrue, reason: '다시 시도할 수 있다');
    });

    testWidgets('이미 등록돼 있으면(409) POST를 반복하지 않고 서버 값으로 맞춘다', (tester) async {
      await openDetail(tester);
      h.favoriteApi.seed([movieId]); // 화면은 모르는 사이에 서버에서 등록됨
      await tester.tap(find.byKey(favoriteButtonKey));
      await settle(tester);
      expect(h.favoriteApi.addCalls, [movieId]);
      expect(h.favoriteApi.checkCalls, hasLength(2));
      expect(filledBookmark(), findsOneWidget);
      expect(find.text('이미 즐겨찾기에 있는 영화예요.'), findsOneWidget);
    });

    testWidgets('이미 없으면(404) DELETE를 반복하지 않고 서버 값으로 맞춘다', (tester) async {
      h.favoriteApi.seed([movieId]);
      await openDetail(tester);
      h.favoriteApi.favoritesOf().clear();
      await tester.tap(find.byKey(favoriteButtonKey));
      await settle(tester);
      expect(h.favoriteApi.deleteCalls, [movieId]);
      expect(emptyBookmark(), findsOneWidget);
      expect(find.text('이미 즐겨찾기에서 삭제된 영화예요.'), findsOneWidget);
    });

    testWidgets('timeout이면 같은 POST를 자동으로 다시 보내지 않고 응답이 늦다고 알린다', (tester) async {
      await openDetail(tester);
      h.favoriteApi.timeoutAfterApply.add('add');
      await tester.tap(find.byKey(favoriteButtonKey));
      await settle(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(h.favoriteApi.addCalls, [movieId], reason: '자동 재시도 없음');
      expect(emptyBookmark(), findsOneWidget);
      expect(find.textContaining('응답이 늦어'), findsOneWidget);
    });
  });

  group('세션', () {
    testWidgets('토큰이 만료되면(AUTH401_3) 로그인 화면으로 가고 만료를 안내한다', (tester) async {
      await openDetail(tester);
      h.favoriteApi.failures['add'] = apiFailure(
        '/favorites',
        401,
        code: 'AUTH401_3',
        message: '토큰 만료',
      );
      await tester.tap(find.byKey(favoriteButtonKey));
      await settle(tester);
      expect(currentLocation(tester), AppRoutes.login);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(h.storage.token, isNull, reason: '만료된 토큰은 지운다');
      expect(h.storage.deletes, 1);
    });

    testWidgets('403은 로그아웃하지 않고 상세 화면에 남는다', (tester) async {
      await openDetail(tester);
      h.favoriteApi.failures['add'] = apiFailure(
        '/favorites',
        403,
        code: 'COMMON403',
        message: '권한 없음',
      );
      await tester.tap(find.byKey(favoriteButtonKey));
      await settle(tester);
      expect(currentLocation(tester), AppRoutes.movieDetail(movieId));
      expect(h.storage.token, isNotNull);
      expect(find.textContaining('즐겨찾기를 등록하지 못했어요'), findsOneWidget);
    });

    testWidgets('요청 중에 상세를 벗어나도 늦게 온 응답은 무시하고 오류도 없다', (tester) async {
      await openDetail(tester);
      h.favoriteApi.gates['add'] = Completer<void>();
      await tester.tap(find.byKey(favoriteButtonKey));
      await tester.pump();
      await tester.tap(find.byType(BackButton));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(MovieDetailScreen), findsNothing);

      h.favoriteApi.gates['add']!.complete();
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('로그아웃한 뒤 같은 영화 상세를 다른 계정으로 열면 이전 계정의 북마크가 남지 않는다', (tester) async {
      // 계정 A(kevin)는 이 영화를 즐겨찾기했고, 계정 B(sue)는 하지 않았다.
      h.favoriteApi.seed([movieId], account: 'kevin@umc.com');
      await openDetail(tester);
      expect(filledBookmark(), findsOneWidget);

      unawaited(authOf(tester).logout());
      await settle(tester);
      expect(currentLocation(tester), AppRoutes.login);

      h.memberApi.member = testMember(email: 'sue@umc.com', nickname: '수');
      h.authApi.accounts['sue@umc.com'] = 'Password1234!';
      await tester.enterText(find.byKey(loginEmailFieldKey), 'sue@umc.com');
      await tester.enterText(find.byKey(loginPasswordFieldKey), 'Password1234!');
      await tester.tap(find.byKey(loginButtonKey));
      await settle(tester);
      await settle(tester);

      goTo(tester, AppRoutes.movieDetail(movieId));
      await settle(tester);
      await settle(tester);
      expect(find.text('파이트 클럽'), findsOneWidget);
      expect(emptyBookmark(), findsOneWidget, reason: 'B는 즐겨찾기하지 않았다');
      expect(filledBookmark(), findsNothing);
    });
  });
}
