import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/features/auth/presentation/login_screen.dart';
import 'package:movielog/features/movies/presentation/movie_detail_screen.dart';
import 'package:movielog/features/movies/presentation/widgets/favorite_button.dart';
import 'package:movielog/features/my_page/presentation/favorites_screen.dart';
import 'package:movielog/features/my_page/presentation/my_page_screen.dart';
import 'package:movielog/widgets/member_session_gate.dart';

import 'support.dart';

/// 마이페이지의 "내 즐겨찾기" 행과 `/my/favorites` 화면.
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

  setUp(() {
    h = AppHarness();
    for (final id in [550, 603, 27205]) {
      h.tmdb.moviesById[id] = movie(id, title: '영화 제목 $id');
    }
  });

  Future<void> openMy(WidgetTester tester) async {
    await tester.pumpWidget(h.app(initialLocation: AppRoutes.my));
    await settle(tester);
  }

  Future<void> openFavoritesFromMy(WidgetTester tester) async {
    await openMy(tester);
    await tester.tap(find.byKey(myFavoritesEntryKey));
    await settle(tester);
    await settle(tester);
  }

  group('마이페이지의 "내 즐겨찾기" 행', () {
    testWidgets('"내가 등록한 평점" 행 바로 아래에 있다', (tester) async {
      await openMy(tester);
      expect(find.text('내 즐겨찾기'), findsOneWidget);
      final ratings = tester.getTopLeft(find.byKey(myRatingsEntryKey)).dy;
      final favorites = tester.getTopLeft(find.byKey(myFavoritesEntryKey)).dy;
      final edit = tester.getTopLeft(find.byKey(editProfileEntryKey)).dy;
      expect(edit, lessThan(ratings));
      expect(ratings, lessThan(favorites), reason: '평점 행 아래');
      // 그 사이에 다른 행이 끼어 있지 않다(행 하나 높이 + 구분선 정도).
      expect(favorites - ratings, lessThan(70));
    });

    testWidgets('내 정보가 준비되기 전에는 행이 없고(로딩), 준비되면 나타난다', (tester) async {
      h.storage.token = null;
      await tester.pumpWidget(h.app());
      await settle(tester);
      h.memberApi.meGate = Completer<void>();
      await tester.enterText(find.byKey(loginEmailFieldKey), 'kevin@umc.com');
      await tester.enterText(find.byKey(loginPasswordFieldKey), 'Password1234!');
      await tester.tap(find.byKey(loginButtonKey));
      await settle(tester);
      await settle(tester);
      await tester.tap(find.text('마이페이지'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(myPageLoadingKey), findsOneWidget);
      expect(find.byKey(myFavoritesEntryKey), findsNothing);

      h.memberApi.meGate!.complete();
      await settle(tester);
      expect(find.byKey(myFavoritesEntryKey), findsOneWidget);
    });

    testWidgets('행을 누르면 /my/favorites로 가고, 하단 NavigationBar 없이 AppBar 중앙 제목과 뒤로가기가 보인다', (
      tester,
    ) async {
      await openMy(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.byKey(myFavoritesEntryKey));
      await settle(tester);
      await settle(tester);

      expect(currentLocation(tester), AppRoutes.myFavorites);
      expect(find.byType(FavoritesScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.centerTitle, isTrue);
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('내 즐겨찾기')),
        findsOneWidget,
      );

      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(currentLocation(tester), AppRoutes.my);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(myFavoritesEntryKey), findsOneWidget);
    });

    testWidgets('주소로 바로 열어도(마이페이지를 거치지 않아도) 내 정보를 준비한 뒤 목록을 보여 준다', (tester) async {
      h.favoriteApi.seed([550]);
      await tester.pumpWidget(h.app(initialLocation: AppRoutes.myFavorites));
      await settle(tester);
      await settle(tester);
      expect(find.byType(FavoritesScreen), findsOneWidget);
      expect(find.byKey(const Key('movieTile-550')), findsOneWidget);
    });
  });

  group('화면 상태 네 가지는 서로 다르다', () {
    testWidgets('목록: 최신 등록순 영화 카드', (tester) async {
      h.favoriteApi.seed([550, 603, 27205]);
      await openFavoritesFromMy(tester);
      expect(find.byKey(favoritesListKey), findsOneWidget);
      expect(find.byKey(favoritesEmptyKey), findsNothing);
      expect(find.byKey(favoritesErrorKey), findsNothing);
      final y27205 = tester.getTopLeft(find.byKey(const Key('movieTile-27205'))).dy;
      final y603 = tester.getTopLeft(find.byKey(const Key('movieTile-603'))).dy;
      final y550 = tester.getTopLeft(find.byKey(const Key('movieTile-550'))).dy;
      expect(y27205, lessThan(y603));
      expect(y603, lessThan(y550));
      expect(find.text('영화 제목 603'), findsOneWidget);
    });

    testWidgets('빈 목록: 안내 문구가 보이고 오류 화면이 아니다', (tester) async {
      await openFavoritesFromMy(tester);
      expect(find.byKey(favoritesEmptyKey), findsOneWidget);
      expect(find.text('아직 즐겨찾기한 영화가 없어요.'), findsOneWidget);
      expect(find.byKey(favoritesListKey), findsNothing);
      expect(find.byKey(favoritesErrorKey), findsNothing);
    });

    testWidgets('조회 오류: 오류 안내와 다시 시도 버튼이 보이고, 누르면 목록으로 복구된다', (tester) async {
      h.favoriteApi.seed([550]);
      h.favoriteApi.failures['list'] = networkFailure('/favorites');
      await openFavoritesFromMy(tester);
      expect(find.byKey(favoritesErrorKey), findsOneWidget);
      expect(find.text('내 즐겨찾기를 불러오지 못했어요.'), findsOneWidget);
      expect(find.byKey(favoritesEmptyKey), findsNothing);
      expect(h.storage.token, isNotNull, reason: '네트워크 실패로 로그아웃하지 않는다');

      h.favoriteApi.failures.clear();
      await tester.tap(find.byKey(favoritesRetryKey));
      await settle(tester);
      expect(find.byKey(favoritesErrorKey), findsNothing);
      expect(find.byKey(const Key('movieTile-550')), findsOneWidget);
    });

    testWidgets('영화 정보 한 건 실패: 그 카드만 "영화 #id"와 다시 조회 버튼이고 나머지 카드는 그대로다', (tester) async {
      h.favoriteApi.seed([550, 603, 27205]);
      h.tmdb.failMovieIds.add(603);
      await openFavoritesFromMy(tester);

      // 목록 전체는 살아 있다(오류·빈 화면이 아니다).
      expect(find.byKey(favoritesListKey), findsOneWidget);
      expect(find.byKey(favoritesErrorKey), findsNothing);
      expect(find.byKey(favoritesEmptyKey), findsNothing);
      expect(find.byKey(const Key('movieTile-550')), findsOneWidget);
      expect(find.byKey(const Key('movieTile-27205')), findsOneWidget);
      // 실패한 한 건만 placeholder.
      expect(find.byKey(const Key('favoritePlaceholder-603')), findsOneWidget);
      expect(find.text('영화 #603'), findsOneWidget);
      expect(find.byKey(const Key('movieTile-603')), findsNothing);
      expect(find.byKey(const Key('favoriteRetryMovie-603')), findsOneWidget);

      // 그 카드만 다시 조회한다.
      h.tmdb.failMovieIds.clear();
      final listCalls = h.favoriteApi.listCalls;
      await tester.tap(find.byKey(const Key('favoriteRetryMovie-603')));
      await settle(tester);
      expect(find.byKey(const Key('movieTile-603')), findsOneWidget);
      expect(find.byKey(const Key('favoritePlaceholder-603')), findsNothing);
      expect(h.favoriteApi.listCalls, listCalls, reason: '목록 전체를 다시 받지 않는다');
    });
  });

  group('상세와 목록의 연동', () {
    testWidgets('카드를 눌러 상세에서 즐겨찾기를 해제하고 돌아오면 목록을 다시 조회해 그 영화가 사라진다', (tester) async {
      h.favoriteApi.seed([550, 603]);
      await openFavoritesFromMy(tester);
      expect(find.byKey(const Key('movieTile-550')), findsOneWidget);
      final listCallsBefore = h.favoriteApi.listCalls;

      await tester.tap(find.byKey(const Key('movieTile-550')));
      await settle(tester);
      await settle(tester);
      expect(currentLocation(tester), AppRoutes.movieDetail(550));
      expect(find.byType(MovieDetailScreen), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);

      await tester.tap(find.byKey(favoriteButtonKey));
      await settle(tester);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      expect(h.favoriteApi.isFavoriteOf(550), isFalse);

      await tester.tap(find.byType(BackButton));
      await settle(tester);
      await settle(tester);
      expect(currentLocation(tester), AppRoutes.myFavorites);
      expect(h.favoriteApi.listCalls, greaterThan(listCallsBefore), reason: '돌아오면 목록을 다시 조회');
      expect(find.byKey(const Key('movieTile-550')), findsNothing);
      expect(find.byKey(const Key('movieTile-603')), findsOneWidget);
    });

    testWidgets('끝까지 해제하면 빈 목록 안내가 보인다', (tester) async {
      h.favoriteApi.seed([550]);
      await openFavoritesFromMy(tester);
      await tester.tap(find.byKey(const Key('movieTile-550')));
      await settle(tester);
      await settle(tester);
      await tester.tap(find.byKey(favoriteButtonKey));
      await settle(tester);
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      await settle(tester);
      expect(find.byKey(favoritesEmptyKey), findsOneWidget);
    });
  });

  group('로그아웃·계정 전환·세션', () {
    Future<void> loginAs(WidgetTester tester, String email) async {
      h.memberApi.member = testMember(email: email, nickname: '수');
      h.authApi.accounts[email] = 'Password1234!';
      await tester.enterText(find.byKey(loginEmailFieldKey), email);
      await tester.enterText(find.byKey(loginPasswordFieldKey), 'Password1234!');
      await tester.tap(find.byKey(loginButtonKey));
      await settle(tester);
      await settle(tester);
    }

    testWidgets('로그아웃하면 이전 계정의 즐겨찾기가 화면에 남지 않고, 다른 계정으로 들어가면 그 계정 목록만 보인다', (
      tester,
    ) async {
      h.favoriteApi.seed([550], account: 'kevin@umc.com');
      h.favoriteApi.seed([603], account: 'sue@umc.com');
      await openFavoritesFromMy(tester);
      expect(find.byKey(const Key('movieTile-550')), findsOneWidget);

      // 즐겨찾기 화면이 떠 있는 채로 로그아웃(세션 정리).
      unawaited(authOf(tester).logout());
      await settle(tester);
      expect(currentLocation(tester), AppRoutes.login);
      expect(find.byType(FavoritesScreen), findsNothing);
      expect(find.byKey(const Key('movieTile-550')), findsNothing);
      expect(find.text('영화 제목 550'), findsNothing);

      await loginAs(tester, 'sue@umc.com');
      await tester.tap(find.text('마이페이지'));
      await settle(tester);
      await tester.tap(find.byKey(myFavoritesEntryKey));
      await settle(tester);
      await settle(tester);
      expect(find.byKey(const Key('movieTile-603')), findsOneWidget);
      expect(find.byKey(const Key('movieTile-550')), findsNothing, reason: '이전 계정(A)의 영화');
    });

    testWidgets('같은 이메일로 다시 로그인해도 새 세션이라 목록을 서버에서 다시 받는다', (tester) async {
      h.favoriteApi.seed([550]);
      await openFavoritesFromMy(tester);
      final first = h.favoriteApi.listCalls;
      unawaited(authOf(tester).logout());
      await settle(tester);
      await loginAs(tester, 'kevin@umc.com');
      await tester.tap(find.text('마이페이지'));
      await settle(tester);
      await tester.tap(find.byKey(myFavoritesEntryKey));
      await settle(tester);
      await settle(tester);
      expect(h.favoriteApi.listCalls, greaterThan(first));
      expect(find.byKey(const Key('movieTile-550')), findsOneWidget);
    });

    testWidgets('이전 세션의 응답이 로그아웃 뒤에 도착해도 다음 계정 화면에 섞이지 않는다', (tester) async {
      h.favoriteApi.seed([550], account: 'kevin@umc.com');
      h.favoriteApi.seed([603], account: 'sue@umc.com');
      h.favoriteApi.gates['list'] = Completer<void>();
      await openMy(tester);
      await tester.tap(find.byKey(myFavoritesEntryKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(favoritesLoadingKey), findsOneWidget);

      unawaited(authOf(tester).logout());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await loginAs(tester, 'sue@umc.com');
      h.favoriteApi.gates['list']!.complete(); // A의 늦은 응답이 이제 도착
      await settle(tester);
      expect(find.byKey(const Key('movieTile-550')), findsNothing);

      await tester.tap(find.text('마이페이지'));
      await settle(tester);
      await tester.tap(find.byKey(myFavoritesEntryKey));
      await settle(tester);
      await settle(tester);
      expect(find.byKey(const Key('movieTile-603')), findsOneWidget);
      expect(find.byKey(const Key('movieTile-550')), findsNothing);
    });

    testWidgets('화면이 떠 있는 채로 계정(email)이 바뀌면 이전 계정의 목록을 버리고 새 계정 목록을 받는다', (tester) async {
      h.favoriteApi.seed([550], account: 'kevin@umc.com');
      h.favoriteApi.seed([603], account: 'sue@umc.com');
      await openFavoritesFromMy(tester);
      expect(find.byKey(const Key('movieTile-550')), findsOneWidget);

      // 로그아웃 없이 내 정보를 다시 받았더니 다른 계정이었다(ValueKey가 ViewModel을 새로 만든다).
      h.memberApi.member = testMember(email: 'sue@umc.com', nickname: '수');
      unawaited(authOf(tester).loadMember(force: true)); // 가짜 응답 지연은 pump로 진행한다
      await settle(tester);
      await settle(tester);
      expect(find.byKey(const Key('movieTile-550')), findsNothing);
      expect(find.byKey(const Key('movieTile-603')), findsOneWidget);
    });

    testWidgets('닉네임이 바뀌어도(email 그대로) 목록 ViewModel은 유지되어 다시 조회하지 않는다', (tester) async {
      h.favoriteApi.seed([550]);
      await openFavoritesFromMy(tester);
      final calls = h.favoriteApi.listCalls;
      final auth = authOf(tester);
      auth.updateMember(testMember(nickname: '새닉네임'));
      await settle(tester);
      expect(h.favoriteApi.listCalls, calls);
      expect(find.byKey(const Key('movieTile-550')), findsOneWidget);
    });

    testWidgets('토큰이 만료되면(AUTH401_2) 로그인 화면으로 간다', (tester) async {
      h.favoriteApi.failures['list'] = apiFailure(
        '/favorites',
        401,
        code: 'AUTH401_2',
        message: '토큰 없음',
      );
      await openFavoritesFromMy(tester);
      expect(currentLocation(tester), AppRoutes.login);
      expect(find.byKey(favoritesErrorKey), findsNothing);
      expect(h.storage.deletes, 1);
    });
  });

  group('내 정보 관문(MemberSessionGate)', () {
    testWidgets('내 정보를 받지 못하면 무한 로딩 대신 오류와 다시 시도 버튼을 보여 주고, 누르면 목록이 열린다', (tester) async {
      h.storage.token = null;
      h.favoriteApi.seed([550]);
      await tester.pumpWidget(h.app(initialLocation: AppRoutes.myFavorites));
      await settle(tester);
      expect(currentLocation(tester), AppRoutes.login);

      h.memberApi.meFailure = networkFailure('/members/me');
      await tester.enterText(find.byKey(loginEmailFieldKey), 'kevin@umc.com');
      await tester.enterText(find.byKey(loginPasswordFieldKey), 'Password1234!');
      await tester.tap(find.byKey(loginButtonKey));
      await settle(tester);
      await settle(tester);
      await settle(tester);
      expect(find.byKey(memberGateErrorKey), findsOneWidget);
      expect(find.byKey(memberGateLoadingKey), findsNothing);
      expect(find.byType(FavoritesScreen), findsNothing);
      expect(h.storage.token, isNotNull, reason: '네트워크 실패로 로그아웃하지 않는다');
      expect(h.favoriteApi.listCalls, 0, reason: '내 정보가 없으면 목록을 요청하지 않는다');

      h.memberApi.meFailure = null;
      await tester.tap(find.byKey(memberGateRetryKey));
      await settle(tester);
      await settle(tester);
      expect(find.byType(FavoritesScreen), findsOneWidget);
      expect(find.byKey(const Key('movieTile-550')), findsOneWidget);
    });

    testWidgets('로그인 직후 상세·즐겨찾기를 바로 열면 내 정보를 한 번 요청한다', (tester) async {
      h.storage.token = null;
      await tester.pumpWidget(h.app(initialLocation: AppRoutes.myFavorites));
      await settle(tester);
      expect(currentLocation(tester), AppRoutes.login);
      await tester.enterText(find.byKey(loginEmailFieldKey), 'kevin@umc.com');
      await tester.enterText(find.byKey(loginPasswordFieldKey), 'Password1234!');
      await tester.tap(find.byKey(loginButtonKey));
      await settle(tester);
      await settle(tester);
      await settle(tester);
      // 로그인 전에 열려던 /my/favorites로 간다. MainShell을 거치지 않아도 gate가 내 정보를 받는다.
      expect(currentLocation(tester), AppRoutes.myFavorites);
      expect(find.byType(FavoritesScreen), findsOneWidget);
      expect(h.memberApi.fetchCalls, 1);
    });
  });
}
