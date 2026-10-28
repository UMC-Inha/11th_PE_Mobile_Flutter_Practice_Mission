import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/core/network/movielog_api_client.dart';
import 'package:movielog/core/network/tmdb_client.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/data/services/movielog_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/features/movies/presentation/movie_list_screen.dart';
import 'package:movielog/features/movies/presentation/widgets/genre_filter_sheet.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_grid.dart';
import 'package:movielog/features/movies/presentation/widgets/retry_dialog.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/widgets/tmdb_poster_image.dart';

import '../support.dart';
import 'live_support.dart';

/// 실제 TMDB + 실제 MovieLog 백엔드(localhost:3000) 응답으로 MovieLog 화면을 그려
/// 인증 이미지·영상 프레임·Network 로그를 남긴다.
///
/// 실행: (백엔드 movie 서버 실행 후) MOVIELOG_LIVE=1 flutter test test/live/live_evidence_test.dart
/// 결과: evidence/week05/*.png, evidence/week05/network-log.txt, evidence/frames/week05-*.png
void main() {
  setUpAll(() => HttpOverrides.global = null); // 진짜 네트워크를 쓴다

  testWidgets(
    '실제 TMDB 응답으로 인기 5개·Discover 30개·장르 재요청 화면을 남긴다',
    skip: liveSkipReason(needsToken: true) != null,
    (tester) async {
      tester.view.physicalSize = const Size(780 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final token = readDotEnv('TMDB_ACCESS_TOKEN');
      final logs = <String>[];
      final tmdb = CachingTmdbService(
        TmdbMovieService(
          createTmdbClient(
            accessToken: token,
            enableLogging: true,
            log: logs.add,
          ),
        ),
        replayDelay: const Duration(milliseconds: 500),
      );
      final api = CachingMovieLogApiService(
        MovieLogApiService(
          createMovieLogApiClient(
            baseUrl: readDotEnv('MOVIELOG_API_BASE_URL').isEmpty
                ? 'http://localhost:3000'
                : readDotEnv('MOVIELOG_API_BASE_URL'),
            enableLogging: true,
            log: logs.add,
          ),
        ),
      );
      final wrongTokenTmdb = CachingTmdbService(
        TmdbMovieService(
          createTmdbClient(
            accessToken: 'wrong-token',
            enableLogging: true,
            log: logs.add,
          ),
        ),
      );

      // ── 1) 실제 서버 호출(진짜 시계) ─────────────────────────────────────
      late List<TmdbMovieDto> popular5;
      late List<TmdbMovieDto> all30;
      late List<TmdbMovieDto> action30;
      late List<TmdbMovieDto> multi30;
      late int discoverPagesAll;
      await tester.runAsync(() async {
        await loadEvidenceFonts();
        final home = MovieHomeViewModel(tmdb);
        await home.loadPopular();
        popular5 = home.popularMovies;

        final list = MovieListViewModel(tmdb);
        await list.loadInitial();
        all30 = list.movies;
        discoverPagesAll = list.discoverRequestCount;
        await list.selectGenre(28);
        action30 = list.movies;
        await list.selectGenres(const [28, 12]);
        multi30 = list.movies;

        await MyRatingsViewModel(api, tmdb).load();
        await api.checkNickname('수현');
        await api.checkNickname('케빈');
        await api.checkEmail('kevin@umc.com');
        await MovieListViewModel(wrongTokenTmdb).loadInitial(); // 실제 401
      });

      // 요구사항 확인: 5개, 30개 이하·중복 없음, 장르 결과는 그 장르를 포함
      expect(popular5, hasLength(5));
      for (final movies in [all30, action30, multi30]) {
        expect(movies.length, lessThanOrEqualTo(30));
        expect(movies.map((m) => m.id).toSet().length, movies.length);
      }
      expect(all30, hasLength(30));
      expect(action30.every((m) => m.genreIds.contains(28)), isTrue);
      expect(
        multi30.every(
          (m) => m.genreIds.contains(28) || m.genreIds.contains(12),
        ),
        isTrue,
      );
      final logText = logs.join('\n');
      expect(logText, isNot(contains(token)));
      expect(logText, contains('with_genres: 28|12'));

      await File('evidence/week05/network-log.txt').create(recursive: true);
      await File('evidence/week05/network-log.txt').writeAsString(
        [
          '# 5주차 실제 요청 로그 (${DateTime.now().toIso8601String()})',
          '# TMDB Token 은 Bearer *** 로 가려져 있다. 응답 Body 는 앞 400자만.',
          '# 인기 ${popular5.length}개 / 전체 Discover ${all30.length}개(page 요청 $discoverPagesAll번) '
              '/ 액션(28) ${action30.length}개 / 액션|모험(28|12) ${multi30.length}개',
          '# 홈 인기 5개: ${popular5.map((m) => '${m.id} ${m.title}').join(', ')}',
          ...logs,
        ].join('\n'),
      );

      // ── 2) 같은 응답으로 실제 화면을 그린다(가짜 시계) ────────────────────
      tmdb.replay = true;
      api.replay = true;
      wrongTokenTmdb.replay = true;
      final network = ValueNotifier<List<String>>([]);
      tmdb.onReplay = (key, result) {
        final parts = key.split(':');
        final line = switch (parts.first) {
          'popular' => 'GET /3/movie/popular?page=${parts[1]}',
          'genres' => 'GET /3/genre/movie/list?language=ko',
          'discover' =>
            'GET /3/discover/movie?page=${parts[1]}'
                '${parts[2].isEmpty ? '' : '&with_genres=${parts[2]}'}',
          _ => 'GET /3/movie/${parts.last}',
        };
        final outcome = result is TmdbMoviePageDto
            ? '200 · ${result.results.length}편 (total_pages ${result.totalPages})'
            : result is Exception
            ? '실패: 연결 오류'
            : '200';
        network.value = [...network.value, '$line\n   → $outcome'];
      };

      final boundaryKey = GlobalKey();
      var frame = 0;
      Future<void> shot(String name) async {
        await tester.runAsync(
          () => saveBoundary(boundaryKey, 'evidence/week05/$name.png'),
        );
      }

      Future<void> frames(
        int count, {
        Duration step = const Duration(milliseconds: 100),
      }) async {
        for (var i = 0; i < count; i++) {
          await tester.pump(step);
          await tester.runAsync(
            () => saveBoundary(
              boundaryKey,
              'evidence/frames/week05-${(frame++).toString().padLeft(3, '0')}.png',
            ),
          );
        }
      }

      Widget stage(Widget app) => Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: boundaryKey,
          child: ColoredBox(
            color: const Color(0xFF1E1B22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 390,
                  child: MediaQuery(
                    data: const MediaQueryData(
                      size: Size(390, 844),
                      devicePixelRatio: 2,
                    ),
                    child: app,
                  ),
                ),
                Expanded(child: _NetworkPanel(lines: network)),
              ],
            ),
          ),
        ),
      );

      final preferences = MemoryMoviePreferences();
      await tester.pumpWidget(
        stage(
          MovieLogApp(
            key: const ValueKey('live'),
            initialLocation: AppRoutes.home,
            tmdbService: tmdb,
            movieLogApiService: api,
            preferences: preferences,
          ),
        ),
      );

      // 포스터는 진짜 이미지 서버에서 받아 캐시에 올린다.
      await tester.runAsync(() async {
        final context = boundaryKey.currentContext!;
        await precachePosters(context, [
          for (final m in tmdb.allMovies) ...[
            ?TmdbPosterImage.imageUrl(m.posterPath, size: 'w342'),
            ?TmdbPosterImage.imageUrl(m.posterPath, size: 'w185'),
          ],
          ?TmdbPosterImage.imageUrl(popular5.first.posterPath),
          ?TmdbPosterImage.imageUrl(all30.first.posterPath),
        ]);
      });

      // 홈: Loading → 인기 5개
      await frames(3);
      await frames(8);
      await tester.pumpAndSettle();
      await shot('01_home_popular5');

      // 영화 탭: Genre API + Discover page 1,2 → 30개
      await tester.tap(find.text('영화').last);
      await frames(4);
      await shot('02_loading');
      await frames(16);
      await tester.pumpAndSettle();
      expect(find.text('전체 · ${all30.length}편'), findsOneWidget);
      await shot('03_discover_30');
      await frames(8);

      // 장르 Chip(액션 28) → with_genres=28 로 page 1부터 다시
      await tester.tap(find.byKey(const Key('genreChip-28')));
      await frames(14);
      await tester.pumpAndSettle();
      await shot('04_genre_action');
      await frames(6);

      // BottomSheet 다중 선택: 액션 + 모험 → with_genres=28|12
      await tester.tap(find.byKey(filterButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('genreCheckbox-12')));
      await tester.pump();
      await shot('05_genre_sheet');
      await frames(6);
      await tester.tap(find.byKey(applyFilterButtonKey));
      await frames(14);
      await tester.pumpAndSettle();
      await shot('06_multi_genre');
      await frames(8);

      // 새로고침 실패 → 목록 유지 + 재시도 Dialog → 다시 시도
      tmdb.failNextDiscover = true;
      await tester.drag(find.byType(MovieGrid), const Offset(0, 420));
      await frames(12);
      await tester.pumpAndSettle();
      expect(find.byType(RetryDialog), findsOneWidget);
      await shot('07_retry_dialog');
      await tester.tap(find.byKey(retryDialogRetryKey));
      await frames(12);
      await tester.pumpAndSettle();
      expect(find.byType(RetryDialog), findsNothing);
      await shot('08_retry_success');

      // 카드 → 상세: Path에 TMDB id
      final first = multi30.first;
      await tester.tap(find.byKey(Key('movieCard-${first.id}')));
      await tester.pumpAndSettle();
      expect(find.text('TMDB 영화 ID ${first.id}'), findsOneWidget);
      await shot('09_detail_movie_id');
      await tester.pageBack();
      await tester.pumpAndSettle();

      // 마이페이지: 자체 백엔드 평점 + movieId 로 찾은 TMDB 제목
      await tester.tap(find.text('마이페이지').last);
      await frames(12);
      await tester.pumpAndSettle();
      await shot('10_my_ratings');

      // 실제 401 → Error 화면
      await tester.pumpWidget(const SizedBox());
      network.value = [];
      await tester.pumpWidget(
        stage(
          MovieLogApp(
            key: const ValueKey('wrong-token'),
            initialLocation: AppRoutes.movies,
            tmdbService: wrongTokenTmdb,
            movieLogApiService: api,
            preferences: MemoryMoviePreferences(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('TMDB 인증에 실패'), findsOneWidget);
      await shot('11_error_401');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}

/// 영상 오른쪽의 Network 패널. 화면 단계에서 나간 요청을 순서대로 보여준다.
class _NetworkPanel extends StatelessWidget {
  const _NetworkPanel({required this.lines});

  final ValueNotifier<List<String>> lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ValueListenableBuilder<List<String>>(
        valueListenable: lines,
        builder: (context, value, _) {
          final recent = value.length > 12
              ? value.sublist(value.length - 12)
              : value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Network (TMDB · Token 가림)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Manrope',
                  fontFamilyFallback: ['Apple SD Gothic Neo'],
                ),
              ),
              const SizedBox(height: 12),
              for (final line in recent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    line,
                    style: TextStyle(
                      color: line.contains('실패')
                          ? const Color(0xFFFF8A80)
                          : line.contains('with_genres')
                          ? const Color(0xFFFFD54F)
                          : const Color(0xFFB9F6CA),
                      fontSize: 12.5,
                      height: 1.35,
                      fontFamily: 'Manrope',
                      fontFamilyFallback: const ['Apple SD Gothic Neo'],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
