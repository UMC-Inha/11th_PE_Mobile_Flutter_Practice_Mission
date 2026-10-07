import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/core/data/mock_movies.dart';
import 'package:movielog/core/services/fake_movie_service.dart';
import 'package:movielog/core/storage/genre_preference.dart';
import 'package:movielog/features/movies/presentation/movie_list_screen.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_grid.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_list_states.dart';

import 'support.dart';

class CountingMovieService implements MovieService {
  int calls = 0;
  @override
  Future<List<Movie>> fetchMovies({
    MovieLoadMode mode = MovieLoadMode.success,
  }) {
    calls++;
    return const FakeMovieService().fetchMovies(mode: mode);
  }
}

void main() {
  test('Mock Service 성공·빈 목록·실패 결과', () async {
    const service = FakeMovieService(delay: Duration.zero);
    expect(await service.fetchMovies(), mockMovies);
    expect(await service.fetchMovies(mode: MovieLoadMode.empty), isEmpty);
    await expectLater(
      service.fetchMovies(mode: MovieLoadMode.failure),
      throwsA(isA<MovieLoadException>()),
    );
  });

  test('늦은 요청은 Future.timeout으로 구분한다', () async {
    const service = FakeMovieService(delay: Duration(milliseconds: 30));
    await expectLater(
      service.fetchMovies().timeout(const Duration(milliseconds: 1)),
      throwsA(isA<TimeoutException>()),
    );
  });

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

  Future<void> completeLoad(WidgetTester tester) async {
    // Future.wait가 저장소 작업까지 완료할 수 있게 한 프레임 더 처리한다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
  }

  testWidgets('최소 800ms Loading 후 Success, 장르·보기 변경은 재요청하지 않는다', (
    tester,
  ) async {
    final service = CountingMovieService();
    await tester.pumpWidget(
      MovieLogApp(
        initialLocation: '/movies',
        movieService: service,
        preferences: MemoryMoviePreferences(),
      ),
    );
    expect(find.byType(MovieListLoading), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(MovieListLoading), findsOneWidget);
    await completeLoad(tester);
    expect(find.byType(MovieGrid), findsOneWidget);
    expect(service.calls, 1);
    await tester.tap(find.byKey(viewModeButtonKey));
    await tester.pump();
    await tester.tap(find.byKey(const Key('genreChip-SF')));
    await tester.pumpAndSettle();
    expect(find.text('SF · 1편'), findsOneWidget);
    expect(service.calls, 1);
  });

  testWidgets('Empty는 안내와 전체 영화 보기로 복구한다', (tester) async {
    await tester.pumpWidget(
      MovieLogApp(
        initialLocation: '/movies?mode=empty',
        preferences: MemoryMoviePreferences(),
      ),
    );
    await completeLoad(tester);
    expect(find.byType(MovieListEmpty), findsOneWidget);
    await tester.tap(find.text('전체 영화 보기'));
    await tester.pump();
    expect(find.byType(MovieListLoading), findsOneWidget);
    await completeLoad(tester);
    expect(find.text('전체 영화 6편'), findsOneWidget);
  });

  testWidgets('Error → 재시도 → Loading → Success', (tester) async {
    final service = CountingMovieService();
    await tester.pumpWidget(
      MovieLogApp(
        initialLocation: '/movies?mode=failure',
        movieService: service,
        preferences: MemoryMoviePreferences(),
      ),
    );
    await completeLoad(tester);
    expect(find.byType(MovieListError), findsOneWidget);
    expect(find.textContaining('MovieLoadException'), findsNothing);
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(find.byType(MovieListLoading), findsOneWidget);
    await completeLoad(tester);
    expect(find.text('전체 영화 6편'), findsOneWidget);
    expect(service.calls, 2);
  });

  testWidgets('시간 초과 안내 후 재시도 성공', (tester) async {
    await tester.pumpWidget(
      MovieLogApp(
        initialLocation: '/movies?mode=timeout',
        preferences: MemoryMoviePreferences(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pumpAndSettle();
    expect(find.text('응답이 늦어지고 있어요.'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    await completeLoad(tester);
    expect(find.byType(MovieGrid), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('장르와 정렬 저장, 새 앱에서 복원, 명시적 Query가 저장값에 우선', (tester) async {
    final preferences = MemoryMoviePreferences();
    await tester.pumpWidget(
      MovieLogApp(
        key: const ValueKey('first'),
        initialLocation: '/movies',
        preferences: preferences,
      ),
    );
    await completeLoad(tester);
    await tester.tap(find.byKey(const Key('genreChip-SF')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movieSort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('평점순').last);
    await tester.pumpAndSettle();
    expect(preferences.settings.genres, {'SF'});
    expect(preferences.settings.sort, MovieSort.rating);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(
      MovieLogApp(
        key: const ValueKey('second'),
        initialLocation: '/movies',
        preferences: preferences,
      ),
    );
    await completeLoad(tester);
    expect(find.text('SF · 1편'), findsOneWidget);
    expect(find.text('평점순'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(
      MovieLogApp(
        key: const ValueKey('third'),
        initialLocation: '/movies?genres=드라마',
        preferences: preferences,
      ),
    );
    await completeLoad(tester);
    expect(find.text('드라마 · 1편'), findsOneWidget);
  });

  testWidgets('당겨서 새로고침은 요청을 한 번 추가한다', (tester) async {
    final service = CountingMovieService();
    await tester.pumpWidget(
      MovieLogApp(
        initialLocation: '/movies',
        movieService: service,
        preferences: MemoryMoviePreferences(),
      ),
    );
    await completeLoad(tester);
    await tester.drag(find.byType(MovieGrid), const Offset(0, 400));
    await tester.pump(const Duration(milliseconds: 500));
    await completeLoad(tester);
    expect(service.calls, 2);
    await completeLoad(tester);
    expect(find.byType(MovieGrid), findsOneWidget);
  });

  testWidgets('로드 완료 전에 화면을 제거해도 setState after dispose가 없다', (tester) async {
    await tester.pumpWidget(
      MovieLogApp(
        initialLocation: '/movies',
        preferences: MemoryMoviePreferences(),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await completeLoad(tester);
    expect(tester.takeException(), isNull);
  });
}
