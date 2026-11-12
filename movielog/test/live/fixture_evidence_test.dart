import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';

import '../support.dart';
import 'live_support.dart';

/// 실제 TMDB에서 일부러 만들기 어려운 Empty·포스터 없음/로드 실패 화면을
/// 가짜 응답으로 그려 인증 이미지로 남긴다. 네트워크는 쓰지 않는다
/// (테스트 기본 HttpClient가 이미지 요청을 바로 실패시켜 errorBuilder 경로를 탄다).
///
/// 실행: MOVIELOG_LIVE=1 flutter test test/live/fixture_evidence_test.dart
void main() {
  testWidgets(
    '가짜 응답으로 Empty·포스터 placeholder 화면을 남긴다',
    skip: liveSkipReason() != null,
    (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(loadEvidenceFonts);
      final boundaryKey = GlobalKey();

      Future<void> open(FakeTmdbMovieService service, String name) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MovieLogApp(
              key: ValueKey(name),
              initialLocation: AppRoutes.movies,
              tmdbService: service,
              movieLogApiService: FakeMovieLogApiService(),
              preferences: MemoryMoviePreferences(),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => saveBoundary(boundaryKey, 'evidence/week05/$name.png'),
        );
      }

      await open(
        FakeTmdbMovieService(perPage: 0, totalPages: 0),
        '12_empty_fixture',
      );
      final noPoster = FakeTmdbMovieService(perPage: 4, totalPages: 1)
        ..discoverPage = (page, genreIds) => TmdbMoviePageDto(
          page: 1,
          results: [
            movie(1, title: 'poster_path가 null', posterPath: null),
            movie(2, title: '이미지 로드 실패', posterPath: '/missing.jpg'),
          ],
          totalPages: 1,
          totalResults: 2,
        );
      await open(noPoster, '13_poster_placeholder_fixture');
      expect(find.text('포스터 없음'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
