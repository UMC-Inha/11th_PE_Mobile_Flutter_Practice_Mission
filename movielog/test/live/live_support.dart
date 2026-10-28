import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/movielog_dtos.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/data/services/movielog_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

/// 실제 서버 응답을 한 번 받아 두고, 같은 요청에는 받아 둔 값을 돌려준다.
///
/// 위젯 테스트의 가짜 시계(FakeAsync) 안에서는 실제 소켓 응답을 기다릴 수 없어서,
/// [warm] 단계(tester.runAsync)에서 진짜 TMDB를 부르고 화면 단계에서는 그 응답을 다시 쓴다.
/// 화면에 보이는 영화·포스터·장르는 전부 실제 TMDB 응답이다.
class CachingTmdbService implements TmdbMovieService {
  CachingTmdbService(this._real, {this.replayDelay = Duration.zero});

  final TmdbMovieService _real;
  final Duration replayDelay;
  final _cache = <String, Object>{};
  bool replay = false;
  final replayedKeys = <String>[];

  /// true면 다음 Discover 요청 한 번을 연결 오류로 실패시킨다(재시도 Dialog 확인용).
  bool failNextDiscover = false;

  /// 화면 단계에서 요청이 나갈 때마다 불린다(영상의 Network 패널).
  void Function(String key, Object result)? onReplay;

  Future<T> _get<T extends Object>(
    String key,
    Future<T> Function() load,
  ) async {
    if (replay) {
      replayedKeys.add(key);
      if (replayDelay > Duration.zero) await Future<void>.delayed(replayDelay);
      if (failNextDiscover && key.startsWith('discover:')) {
        failNextDiscover = false;
        final error = DioException(
          requestOptions: RequestOptions(path: '/discover/movie'),
          type: DioExceptionType.connectionError,
          message: 'network off (재현)',
        );
        onReplay?.call(key, error);
        throw error;
      }
      final cached = _cache[key];
      if (cached == null) throw StateError('녹화되지 않은 요청: $key');
      onReplay?.call(key, cached);
      if (cached is _Failure) throw cached.error;
      return cached as T;
    }
    try {
      final value = await load();
      _cache[key] = value;
      return value;
    } catch (error) {
      // 실제 서버가 준 실패(예: 401)도 그대로 녹화해 화면 단계에서 다시 던진다.
      _cache[key] = _Failure(error);
      rethrow;
    }
  }

  Iterable<TmdbMovieDto> get allMovies sync* {
    for (final value in _cache.values) {
      if (value is TmdbMoviePageDto) yield* value.results;
      if (value is TmdbMovieDto) yield value;
    }
  }

  @override
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) =>
      _get('popular:$page', () => _real.fetchPopular(page: page));

  @override
  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    List<int>? genreIds,
    CancelToken? cancelToken,
  }) => _get(
    'discover:$page:${withGenresQuery(genreIds ?? const [])}',
    () => _real.discoverMovies(page: page, genreIds: genreIds),
  );

  @override
  Future<List<TmdbGenreDto>> fetchGenres() =>
      _get('genres', () => _real.fetchGenres());

  @override
  Future<TmdbMovieDto> fetchMovie(int movieId) =>
      _get('movie:$movieId', () => _real.fetchMovie(movieId));
}

class _Failure {
  const _Failure(this.error);
  final Object error;
}

class CachingMovieLogApiService implements MovieLogApiService {
  CachingMovieLogApiService(this._real);

  final MovieLogApiService _real;
  final _cache = <String, Object>{};
  bool replay = false;

  Future<T> _get<T extends Object>(
    String key,
    Future<T> Function() load,
  ) async {
    if (replay) {
      final cached = _cache[key];
      if (cached == null) throw StateError('녹화되지 않은 요청: $key');
      return cached as T;
    }
    final value = await load();
    _cache[key] = value;
    return value;
  }

  @override
  Future<AvailabilityDto> checkNickname(String nickname) =>
      _get('nickname:$nickname', () => _real.checkNickname(nickname));

  @override
  Future<AvailabilityDto> checkEmail(String email) =>
      _get('email:$email', () => _real.checkEmail(email));

  @override
  Future<List<MemberRatingDto>> fetchMemberRatings(int memberId) =>
      _get('ratings:$memberId', () => _real.fetchMemberRatings(memberId));
}

/// 실제 서버를 부르는 테스트는 MOVIELOG_LIVE=1 일 때만 돈다.
String? liveSkipReason({bool needsToken = false}) {
  if (Platform.environment['MOVIELOG_LIVE'] != '1') {
    return '실제 네트워크 테스트: MOVIELOG_LIVE=1 flutter test test/live 로 실행';
  }
  if (needsToken && readDotEnv('TMDB_ACCESS_TOKEN').isEmpty) {
    return '.env 의 TMDB_ACCESS_TOKEN 이 비어 있습니다';
  }
  return null;
}

/// .env 를 직접 읽는다(값은 출력하지 않는다).
String readDotEnv(String key) {
  final file = File('.env');
  if (!file.existsSync()) return '';
  for (final line in file.readAsLinesSync()) {
    final index = line.indexOf('=');
    if (index > 0 && line.substring(0, index).trim() == key) {
      return line.substring(index + 1).trim();
    }
  }
  return '';
}

/// 인증 화면용 폰트(Manrope·한글·Material 아이콘)를 실제로 불러온다.
Future<void> loadEvidenceFonts() async {
  final manrope = FontLoader('Manrope')
    ..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'));
  await manrope.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
  final korean = File('/System/Library/Fonts/AppleSDGothicNeo.ttc');
  if (await korean.exists()) {
    final fallback = FontLoader('Apple SD Gothic Neo')
      ..addFont(Future.value(ByteData.sublistView(await korean.readAsBytes())));
    await fallback.load();
  }
}

Future<void> saveBoundary(GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).create(recursive: true);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}

/// 받아 둔 포스터를 실제로 내려받아 이미지 캐시에 올려 둔다(가짜 시계 밖에서).
Future<void> precachePosters(
  BuildContext context,
  Iterable<String> urls,
) async {
  for (final url in urls.toSet()) {
    try {
      await precacheImage(NetworkImage(url), context);
    } catch (_) {
      // 실패한 포스터는 화면에서 placeholder로 보인다.
    }
  }
}
