import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/features/movies/presentation/movie_detail_screen.dart';
import 'package:movielog/features/movies/presentation/movie_list_screen.dart';
import 'package:movielog/features/movies/presentation/movie_search_screen.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_grid.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_page_footer.dart';
import 'package:movielog/widgets/movielog_button.dart';

import 'support.dart';

/// 영화 목록의 "더 보기"와 영화 검색 화면.
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
  late FakeTmdbMovieService tmdb;

  setUp(() {
    h = AppHarness();
    tmdb = h.tmdb;
  });

  Future<void> openMovies(WidgetTester tester) async {
    await tester.pumpWidget(h.app(initialLocation: AppRoutes.movies));
    await settle(tester);
    await settle(tester);
  }

  Finder gridScrollable() => find.descendant(
    of: find.byType(MovieGrid),
    matching: find.byType(Scrollable),
  );

  Future<void> scrollToFooter(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      500,
      scrollable: gridScrollable(),
    );
    await tester.pump();
  }

  group('영화 목록: 첫 page와 더 보기 footer', () {
    testWidgets('첫 page 20편만 받고(Discover를 한 번만 호출) 맨 아래에 "더 보기" 버튼이 있다', (tester) async {
      tmdb.totalPages = 3;
      await openMovies(tester);
      expect(tmdb.discoverCalls.map((c) => c.page), [1]);
      expect(find.text('전체 · 20편'), findsOneWidget);
      await scrollToFooter(tester, find.byKey(loadMoreButtonKey));
      expect(find.byKey(loadMoreButtonKey), findsOneWidget);
      expect(find.text('더 보기'), findsOneWidget);
      expect(find.byKey(moviePageEndKey), findsNothing);
    });

    testWidgets('더 보기를 누르면 다음 page가 이어 붙고 목록은 그대로 남는다', (tester) async {
      tmdb.totalPages = 3;
      await openMovies(tester);
      await scrollToFooter(tester, find.byKey(loadMoreButtonKey));
      await tester.tap(find.byKey(loadMoreButtonKey));
      await settle(tester);
      expect(tmdb.discoverCalls.map((c) => c.page), [1, 2]);
      expect(find.text('전체 · 40편'), findsOneWidget);
      // 첫 page의 영화(id 1)도 그대로 있다.
      await tester.drag(gridScrollable(), const Offset(0, 6000));
      await tester.pump();
      expect(find.byKey(const Key('movieCard-1')), findsOneWidget);
    });

    testWidgets('다음 page를 받는 중에는 "더 보기" 버튼이 로딩으로 바뀌어 눌리지 않고 요청은 한 번이다', (tester) async {
      tmdb.totalPages = 3;
      await openMovies(tester);
      await scrollToFooter(tester, find.byKey(loadMoreButtonKey));
      tmdb.gate = Completer<void>();
      await tester.tap(find.byKey(loadMoreButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final button = tester.widget<MovieLogButton>(find.byKey(loadMoreButtonKey));
      expect(button.isLoading, isTrue);
      // 기존 목록은 그대로 보인다.
      expect(find.text('전체 · 20편'), findsOneWidget);
      await tester.tap(find.byKey(loadMoreButtonKey), warnIfMissed: false);
      await tester.pump();
      expect(tmdb.discoverCalls.map((c) => c.page), [1, 2]);

      tmdb.gate!.complete();
      await settle(tester);
      expect(find.text('전체 · 40편'), findsOneWidget);
    });

    testWidgets('다음 page 조회가 실패하면 목록을 지우지 않고 오류와 "다시 시도"가 보이며, 같은 page를 다시 요청한다', (
      tester,
    ) async {
      tmdb.totalPages = 3;
      await openMovies(tester);
      await scrollToFooter(tester, find.byKey(loadMoreButtonKey));
      tmdb.failDiscover = true;
      await tester.tap(find.byKey(loadMoreButtonKey));
      await settle(tester);
      await scrollToFooter(tester, find.byKey(loadMoreRetryKey));
      expect(find.byKey(loadMoreErrorKey), findsOneWidget);
      expect(find.byKey(loadMoreRetryKey), findsOneWidget);
      expect(find.byKey(loadMoreButtonKey), findsNothing);
      expect(find.text('전체 · 20편'), findsOneWidget, reason: '기존 목록은 그대로');

      tmdb.failDiscover = false;
      await tester.tap(find.byKey(loadMoreRetryKey));
      await settle(tester);
      expect(tmdb.discoverCalls.map((c) => c.page), [1, 2, 2], reason: '같은 page 재시도');
      expect(find.text('전체 · 40편'), findsOneWidget);
      expect(find.byKey(loadMoreErrorKey), findsNothing);
    });

    testWidgets('마지막 page를 받으면 더 보기 버튼 대신 끝 안내가 보인다', (tester) async {
      tmdb.totalPages = 2;
      await openMovies(tester);
      await scrollToFooter(tester, find.byKey(loadMoreButtonKey));
      await tester.tap(find.byKey(loadMoreButtonKey));
      await settle(tester);
      await scrollToFooter(tester, find.byKey(moviePageEndKey));
      expect(find.byKey(moviePageEndKey), findsOneWidget);
      expect(find.byKey(loadMoreButtonKey), findsNothing);
      expect(find.text('전체 · 40편'), findsOneWidget);
    });

    testWidgets('page가 하나뿐이면 처음부터 끝 안내만 보인다', (tester) async {
      tmdb.totalPages = 1;
      await openMovies(tester);
      await scrollToFooter(tester, find.byKey(moviePageEndKey));
      expect(find.byKey(moviePageEndKey), findsOneWidget);
      expect(find.byKey(loadMoreButtonKey), findsNothing);
    });

    testWidgets('장르를 바꾸면 목록·page를 모두 비우고 page 1부터 다시 받는다', (tester) async {
      tmdb.totalPages = 3;
      await openMovies(tester);
      await scrollToFooter(tester, find.byKey(loadMoreButtonKey));
      await tester.tap(find.byKey(loadMoreButtonKey));
      await settle(tester);
      expect(find.text('전체 · 40편'), findsOneWidget);

      await tester.drag(gridScrollable(), const Offset(0, 6000));
      await tester.pump();
      await tester.tap(find.byKey(const Key('genreChip-18')));
      await settle(tester);
      expect(find.text('드라마 · 20편'), findsOneWidget, reason: '40편이 아니라 새 조건의 첫 page');
      expect(tmdb.discoverCalls.last.page, 1);
      expect(tmdb.discoverCalls.last.genreIds, [18]);
    });

    testWidgets('이전 장르의 느린 응답이 새 장르 목록을 덮지 않는다(요청 순서와 반대로 도착)', (tester) async {
      await openMovies(tester);
      final slow = Completer<void>();
      tmdb.beforeResponse = (call) async {
        if (call.genreIds?.first == 12) await slow.future;
      };
      await tester.tap(find.byKey(const Key('genreChip-12'))); // 느림
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('genreChip-18'))); // 나중에 눌렀지만 먼저 끝남
      await settle(tester);
      expect(find.text('드라마 · 20편'), findsOneWidget);

      slow.complete(); // 모험(12)의 응답이 이제야 도착
      await settle(tester);
      expect(find.text('드라마 · 20편'), findsOneWidget);
      expect(find.text('모험 · 20편'), findsNothing);
    });

    testWidgets('홈의 인기 영화 요청에는 영향이 없다(목록 화면이 홈 API를 대신 부르지 않는다)', (tester) async {
      await openMovies(tester);
      expect(tmdb.popularCalls, 0);
    });
  });

  group('영화 검색', () {
    Future<void> openSearchFromList(WidgetTester tester) async {
      await openMovies(tester);
      await tester.tap(find.byKey(movieSearchButtonKey));
      await settle(tester);
    }

    Future<void> submit(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(movieSearchFieldKey), text);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
    }

    testWidgets('영화 목록 AppBar 오른쪽의 검색 아이콘을 누르면 검색 화면으로 가고 하단 NavigationBar가 없다', (
      tester,
    ) async {
      await openMovies(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
      // 검색 아이콘은 AppBar 오른쪽(actions의 마지막)이다.
      final filterX = tester.getCenter(find.byKey(filterButtonKey)).dx;
      final searchX = tester.getCenter(find.byKey(movieSearchButtonKey)).dx;
      expect(searchX, greaterThan(filterX));

      await tester.tap(find.byKey(movieSearchButtonKey));
      await settle(tester);
      expect(currentLocation(tester), AppRoutes.movieSearch);
      expect(find.byType(MovieSearchScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
      expect(tester.widget<AppBar>(find.byType(AppBar)).centerTitle, isTrue);
      expect(find.byKey(searchIdleKey), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.byType(MovieListScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('/movies/search를 주소로 열면 영화 id "search"로 해석되지 않고 검색 화면이 열린다', (tester) async {
      await tester.pumpWidget(h.app(initialLocation: AppRoutes.movieSearch));
      await settle(tester);
      expect(find.byType(MovieSearchScreen), findsOneWidget);
      expect(find.byType(MovieDetailScreen), findsNothing);
      expect(find.text('영화를 찾을 수 없어요.'), findsNothing);
      expect(tmdb.movieCalls, isEmpty, reason: '영화 상세를 조회하지 않는다');
    });

    testWidgets('처음(idle)에는 안내만 보이고 아무것도 요청하지 않는다', (tester) async {
      await openSearchFromList(tester);
      expect(find.byKey(searchIdleKey), findsOneWidget);
      expect(find.byKey(searchResultsKey), findsNothing);
      expect(find.byKey(searchEmptyKey), findsNothing);
      expect(find.byKey(searchErrorKey), findsNothing);
      expect(tmdb.searchCalls, isEmpty);
    });

    testWidgets('검색 키로 제출하면 기다리지 않고 바로 요청한다(debounce와 별개로 유지)', (tester) async {
      await openSearchFromList(tester);
      await tester.enterText(find.byKey(movieSearchFieldKey), '매트릭스');
      await tester.pump(const Duration(milliseconds: 100));
      expect(tmdb.searchCalls, isEmpty);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(tmdb.searchCalls.map((c) => c.query), ['매트릭스'], reason: '500ms를 기다리지 않는다');
      await settle(tester);
      // 제출로 대기 중이던 자동 검색은 취소되어 같은 검색어가 두 번 나가지 않는다.
      await tester.pump(const Duration(seconds: 2));
      expect(tmdb.searchCalls, hasLength(1));
    });

    group('입력만으로 검색(Challenge A: debounce 500ms)', () {
      testWidgets('입력하고 500ms가 지나기 전에는 요청이 없고, 지나면 한 번만 요청한다', (tester) async {
        await openSearchFromList(tester);
        await tester.enterText(find.byKey(movieSearchFieldKey), '매트릭스');
        await tester.pump(const Duration(milliseconds: 499));
        expect(tmdb.searchCalls, isEmpty);
        await tester.pump(const Duration(milliseconds: 2));
        expect(tmdb.searchCalls.map((c) => (c.page, c.query)), [(1, '매트릭스')]);
        await settle(tester);
        await tester.pump(const Duration(seconds: 3));
        expect(tmdb.searchCalls, hasLength(1), reason: '한 번 입력에 요청은 한 번');
        expect(find.byKey(searchResultsKey), findsOneWidget);
      });

      testWidgets('연속으로 입력하면 이전 타이머를 취소하고 마지막 입력만 요청한다', (tester) async {
        await openSearchFromList(tester);
        await tester.enterText(find.byKey(movieSearchFieldKey), '매');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.enterText(find.byKey(movieSearchFieldKey), '매트');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.enterText(find.byKey(movieSearchFieldKey), '매트릭스');
        await tester.pump(const Duration(milliseconds: 300));
        expect(tmdb.searchCalls, isEmpty, reason: '마지막 입력 뒤 500ms가 아직 안 지났다');
        await tester.pump(const Duration(milliseconds: 250));
        await settle(tester);
        expect(tmdb.searchCalls.map((c) => c.query), ['매트릭스']);
      });

      testWidgets('앞뒤 공백은 trim해서 요청한다', (tester) async {
        await openSearchFromList(tester);
        await tester.enterText(find.byKey(movieSearchFieldKey), '   매트릭스   ');
        await tester.pump(const Duration(milliseconds: 600));
        await settle(tester);
        expect(tmdb.searchCalls.single, (page: 1, query: '매트릭스'));
      });

      testWidgets('빈 값·공백뿐인 값은 요청하지 않고 입력 안내도 띄우지 않는다', (tester) async {
        await openSearchFromList(tester);
        await tester.enterText(find.byKey(movieSearchFieldKey), '   ');
        await tester.pump(const Duration(seconds: 1));
        await tester.enterText(find.byKey(movieSearchFieldKey), '');
        await tester.pump(const Duration(seconds: 1));
        expect(tmdb.searchCalls, isEmpty);
        expect(find.text('검색어를 입력해 주세요.'), findsNothing);
        expect(find.byKey(searchIdleKey), findsOneWidget);
      });

      testWidgets('입력 후 지웠다면 대기 중이던 검색은 실행되지 않는다', (tester) async {
        await openSearchFromList(tester);
        await tester.enterText(find.byKey(movieSearchFieldKey), '매트릭스');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.enterText(find.byKey(movieSearchFieldKey), '');
        await tester.pump(const Duration(seconds: 1));
        expect(tmdb.searchCalls, isEmpty);
      });

      testWidgets('화면을 벗어나면 대기 중인 타이머가 취소되어 요청도 오류도 없다', (tester) async {
        await openSearchFromList(tester);
        await tester.enterText(find.byKey(movieSearchFieldKey), '매트릭스');
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.byType(BackButton));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(MovieSearchScreen), findsNothing);
        await tester.pump(const Duration(seconds: 2));
        expect(tmdb.searchCalls, isEmpty, reason: 'dispose에서 타이머를 취소했다');
        expect(tester.takeException(), isNull);
      });

      testWidgets('먼저 시작한 느린 검색의 응답은 나중 입력의 결과를 덮지 않는다(generation)', (tester) async {
        await openSearchFromList(tester);
        final slow = Completer<void>();
        tmdb.beforeResponse = (call) async {
          if (call.query == '느린') await slow.future;
        };
        await tester.enterText(find.byKey(movieSearchFieldKey), '느린');
        await tester.pump(const Duration(milliseconds: 600)); // '느린' 요청이 나가고 응답은 붙잡힘
        await tester.enterText(find.byKey(movieSearchFieldKey), '빠른');
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.textContaining('빠른 결과 1'), findsOneWidget);

        slow.complete();
        await settle(tester);
        expect(find.textContaining('느린 결과'), findsNothing);
        expect(find.textContaining('빠른 결과 1'), findsOneWidget);
        expect(tmdb.searchCalls.map((c) => c.query), ['느린', '빠른']);
      });
    });

    testWidgets('빈 검색어(공백 포함)는 서버로 보내지 않고 입력 안내만 보인다', (tester) async {
      await openSearchFromList(tester);
      await submit(tester, '');
      expect(tmdb.searchCalls, isEmpty);
      expect(find.text('검색어를 입력해 주세요.'), findsOneWidget);
      expect(find.byKey(searchIdleKey), findsOneWidget);

      await tester.enterText(find.byKey(movieSearchFieldKey), '   ');
      await tester.tap(find.byKey(movieSearchSubmitKey));
      await settle(tester);
      expect(tmdb.searchCalls, isEmpty);
      expect(tmdb.discoverCalls.map((c) => c.page), [1], reason: '목록 API로 새지도 않는다');
    });

    testWidgets('제출하면 로딩 뒤 결과 목록(상태: 결과)이 보이고 검색어는 trim해서 보낸다', (tester) async {
      await openSearchFromList(tester);
      tmdb.gate = Completer<void>();
      await tester.enterText(find.byKey(movieSearchFieldKey), '  매트릭스  ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(searchLoadingKey), findsOneWidget);
      expect(find.byKey(searchIdleKey), findsNothing);

      tmdb.gate!.complete();
      await settle(tester);
      expect(find.byKey(searchResultsKey), findsOneWidget);
      expect(find.byKey(searchLoadingKey), findsNothing);
      expect(tmdb.searchCalls.single, (page: 1, query: '매트릭스'));
      expect(find.textContaining('매트릭스 결과 1'), findsOneWidget);
    });

    testWidgets('검색 아이콘 버튼으로도 제출할 수 있다', (tester) async {
      await openSearchFromList(tester);
      await tester.enterText(find.byKey(movieSearchFieldKey), '인셉션');
      await tester.tap(find.byKey(movieSearchSubmitKey));
      await settle(tester);
      expect(tmdb.searchCalls.map((c) => c.query), ['인셉션']);
    });

    testWidgets('결과가 없으면 "결과 없음" 화면이다(idle·오류와 다르다)', (tester) async {
      tmdb.searchPage = (page, query) => const TmdbMoviePageDto(
        page: 1,
        results: [],
        totalPages: 0,
        totalResults: 0,
      );
      await openSearchFromList(tester);
      await submit(tester, '없는영화');
      expect(find.byKey(searchEmptyKey), findsOneWidget);
      expect(find.textContaining('"없는영화" 검색 결과가 없어요.'), findsOneWidget);
      expect(find.byKey(searchIdleKey), findsNothing);
      expect(find.byKey(searchErrorKey), findsNothing);
      expect(find.byKey(searchResultsKey), findsNothing);
    });

    testWidgets('검색이 실패하면 오류 화면이고, 다시 시도는 마지막으로 검색한 검색어로 요청한다', (tester) async {
      await openSearchFromList(tester);
      tmdb.failSearch = true;
      await submit(tester, '매트릭스');
      expect(find.byKey(searchErrorKey), findsOneWidget);
      expect(find.byKey(searchEmptyKey), findsNothing);

      tmdb.failSearch = false;
      await tester.tap(find.byKey(searchRetryKey));
      await settle(tester);
      expect(find.byKey(searchResultsKey), findsOneWidget);
      expect(tmdb.searchCalls.map((c) => (c.page, c.query)), [
        (1, '매트릭스'),
        (1, '매트릭스'),
      ]);
    });

    testWidgets('결과도 "더 보기"로 같은 검색어의 다음 page를 이어 받는다', (tester) async {
      tmdb.totalPages = 3;
      await openSearchFromList(tester);
      await submit(tester, '매트릭스');
      await tester.scrollUntilVisible(
        find.byKey(loadMoreButtonKey),
        400,
        scrollable: find
            .descendant(
              of: find.byKey(searchResultsKey),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(loadMoreButtonKey));
      await settle(tester);
      expect(
        tmdb.searchCalls.map((c) => (c.page, c.query)),
        [(1, '매트릭스'), (2, '매트릭스')],
      );
      expect(find.textContaining('매트릭스 결과 21'), findsWidgets);
    });

    testWidgets('새 검색어를 제출하면 이전 결과를 비우고 page 1부터 다시 받는다', (tester) async {
      await openSearchFromList(tester);
      await submit(tester, '가나다');
      expect(find.textContaining('가나다 결과 1'), findsOneWidget);
      await submit(tester, '라마바');
      expect(find.textContaining('가나다 결과'), findsNothing);
      expect(find.textContaining('라마바 결과 1'), findsOneWidget);
      expect(tmdb.searchCalls.map((c) => (c.page, c.query)), [(1, '가나다'), (1, '라마바')]);
    });

    testWidgets('이전 검색어의 느린 응답이 새 검색어 결과에 섞이지 않는다', (tester) async {
      await openSearchFromList(tester);
      final slow = Completer<void>();
      tmdb.beforeResponse = (call) async {
        if (call.query == '느린검색') await slow.future;
      };
      await tester.enterText(find.byKey(movieSearchFieldKey), '느린검색');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await submit(tester, '빠른검색');
      expect(find.textContaining('빠른검색 결과 1'), findsOneWidget);

      slow.complete();
      await settle(tester);
      expect(find.textContaining('느린검색 결과'), findsNothing);
      expect(find.textContaining('빠른검색 결과 1'), findsOneWidget);
    });

    testWidgets('결과 카드를 누르면 영화 상세로 가고, 뒤로 오면 검색 결과가 그대로 남아 있다', (tester) async {
      tmdb.searchPage = (page, query) => TmdbMoviePageDto(
        page: page,
        results: [movie(550, title: '파이트 클럽')],
        totalPages: 1,
        totalResults: 1,
      );
      await openSearchFromList(tester);
      await submit(tester, '파이트');
      await tester.tap(find.byKey(const Key('movieTile-550')));
      await settle(tester);
      await settle(tester);
      expect(currentLocation(tester), AppRoutes.movieDetail(550));
      expect(find.byType(MovieDetailScreen), findsOneWidget);
      expect(find.text('파이트 클럽'), findsWidgets);

      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.byType(MovieSearchScreen), findsOneWidget);
      expect(find.byKey(const Key('movieTile-550')), findsOneWidget);
    });

    testWidgets('검색 화면은 영화 목록과 별도의 ViewModel이라 목록의 페이지 상태에 영향을 주지 않는다', (tester) async {
      tmdb.totalPages = 3;
      await openSearchFromList(tester);
      await submit(tester, '매트릭스');
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.text('전체 · 20편'), findsOneWidget);
      expect(
        tmdb.discoverCalls.map((c) => c.page),
        [1],
        reason: '검색이 목록의 nextPage·결과를 건드리지 않는다',
      );
    });
  });
}
