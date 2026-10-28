import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/network/tmdb_client.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

import 'live_support.dart';

/// Challenge: 네트워크 로그 - 요청 실패 재현 (실제 TMDB 서버에 잘못된 Token으로 요청)
///
/// 실행: MOVIELOG_LIVE=1 flutter test test/live/tmdb_failure_log_test.dart
/// 결과: evidence/week05/network-failure-log.txt
/// 평소 `flutter test`에서는 네트워크를 쓰지 않도록 건너뛴다.
void main() {
  setUpAll(() => HttpOverrides.global = null); // 진짜 네트워크를 쓴다

  test('잘못된 Token → 실제 401, 로그에 URL·오류는 남고 Token 원문은 없다', skip: liveSkipReason(), () async {
    const wrongToken = 'wrong-token-for-week05-test';
    final logs = <String>[];
    final service = TmdbMovieService(
      createTmdbClient(
        accessToken: wrongToken,
        enableLogging: true,
        log: logs.add,
      ),
    );

    DioException? failure;
    try {
      await service.discoverMovies(page: 1, genreIds: const [28, 12]);
    } on DioException catch (error) {
      failure = error;
    }

    expect(failure?.response?.statusCode, 401);
    final all = logs.join('\n');
    expect(
      all,
      contains('[TMDB 오류] https://api.themoviedb.org/3/discover/movie'),
    );
    expect(all, contains('with_genres=28%7C12'));
    expect(all, contains('status=401'));
    expect(all, contains('Bearer ***'));
    expect(all, isNot(contains(wrongToken)));

    // release 모드와 같은 조건(enableLogging=false)에서는 한 줄도 남지 않는다.
    final releaseLogs = <String>[];
    final release = TmdbMovieService(
      createTmdbClient(
        accessToken: wrongToken,
        enableLogging: false,
        log: releaseLogs.add,
      ),
    );
    await expectLater(release.fetchPopular(), throwsA(isA<DioException>()));
    expect(releaseLogs, isEmpty);

    // 진짜 Token이 .env에 있으면 그 값도 로그에 없는지 한 번 더 본다.
    final realToken = readDotEnv('TMDB_ACCESS_TOKEN');
    if (realToken.isNotEmpty) expect(all, isNot(contains(realToken)));

    final file = File('evidence/week05/network-failure-log.txt');
    await file.create(recursive: true);
    await file.writeAsString(
      [
        '# 5주차 Challenge — 네트워크 로그 요청 실패 재현',
        '# ${DateTime.now().toIso8601String()} 실제 api.themoviedb.org 에 잘못된 Token으로 요청',
        '# (debug 로그) — Authorization 은 Bearer *** 로 가려짐',
        ...logs,
        '',
        '# release 조건(kDebugMode=false → Interceptor 미등록) 같은 요청의 로그 줄 수: ${releaseLogs.length}',
      ].join('\n'),
    );
  });
}
