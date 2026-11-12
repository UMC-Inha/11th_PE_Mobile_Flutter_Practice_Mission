import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/network/movielog_api_client.dart';
import 'package:movielog/core/network/tmdb_client.dart';
import 'package:movielog/core/network/tmdb_logging_interceptor.dart';
import 'package:movielog/core/storage/genre_preference.dart';
import 'package:movielog/data/models/movielog_dtos.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/data/services/movielog_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/widgets/tmdb_poster_image.dart';

/// 실제 서버 대신 요청을 기록하고 정해 둔 JSON을 돌려주는 Dio 어댑터.
class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this.respond);

  final (int, Object) Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = respond(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> pageJson(List<Map<String, dynamic>> results) => {
  'page': 1,
  'results': results,
  'total_pages': 3,
  'total_results': 60,
};

void main() {
  group('DTO 변환', () {
    test('snake_case → lowerCamelCase, num → int/double', () {
      final dto = TmdbMovieDto.fromJson({
        'id': 550,
        'title': '파이트 클럽',
        'overview': '줄거리',
        'poster_path': '/a.jpg',
        'backdrop_path': '/b.jpg',
        'release_date': '1999-10-15',
        'genre_ids': [18, 53],
        'vote_average': 8, // 정수로 와도 double로 받는다
        'popularity': 61.4,
      });
      expect(dto.id, 550);
      expect(dto.posterPath, '/a.jpg');
      expect(dto.backdropPath, '/b.jpg');
      expect(dto.genreIds, [18, 53]);
      expect(dto.voteAverage, 8.0);
      expect(dto.voteAverage, isA<double>());
    });

    test('null·빈 문자열·누락 필드는 안전한 기본값', () {
      final dto = TmdbMovieDto.fromJson({
        'id': 1.0,
        'title': '',
        'poster_path': null,
        'release_date': '',
      });
      expect(dto.id, 1);
      expect(dto.title, '제목 없음');
      expect(dto.overview, '');
      expect(dto.posterPath, isNull);
      expect(dto.releaseDate, isNull);
      expect(dto.genreIds, isEmpty);
      expect(dto.voteAverage, 0);
    });

    test('상세 응답의 genres: [{id, name}] 도 id 목록으로 바꾼다', () {
      final dto = TmdbMovieDto.fromJson({
        'id': 155,
        'title': '다크 나이트',
        'genres': [
          {'id': 18, 'name': '드라마'},
          {'id': 28, 'name': '액션'},
        ],
      });
      expect(dto.genreIds, [18, 28]);
    });

    test('페이지 DTO와 장르 DTO', () {
      final page = TmdbMoviePageDto.fromJson(
        pageJson([
          {'id': 1, 'title': 'A'},
          {'id': 2, 'title': 'B'},
        ]),
      );
      expect(page.results.map((m) => m.id), [1, 2]);
      expect(page.totalPages, 3);
      expect(TmdbGenreDto.fromJson({'id': 28, 'name': '액션'}).name, '액션');
    });

    test('자체 백엔드 DTO와 평점 요청 Body', () {
      final rating = MemberRatingDto.fromJson({
        'ratingId': 2,
        'movieId': 155,
        'score': 4,
        'comment': null,
        'createdAt': '2026-10-28T13:46:01.000Z',
        'updatedAt': '2026-10-28T13:46:01.000Z',
      });
      expect(rating.movieId, 155);
      expect(rating.comment, isNull);
      expect(const CreateRatingRequest(movieId: 550, score: 5).toJson(), {
        'movieId': 550,
        'score': 5,
      });
    });
  });

  test('poster_path → 이미지 URL, 비면 null', () {
    expect(
      TmdbPosterImage.imageUrl('/a.jpg'),
      'https://image.tmdb.org/t/p/w500/a.jpg',
    );
    expect(
      TmdbPosterImage.imageUrl('a.jpg', size: 'w185'),
      'https://image.tmdb.org/t/p/w185/a.jpg',
    );
    expect(TmdbPosterImage.imageUrl(null), isNull);
    expect(TmdbPosterImage.imageUrl(' '), isNull);
  });

  test('저장된 장르 ID 문자열 해석', () {
    expect(parseGenreIds('28,12'), [28, 12]);
    expect(parseGenreIds('28|12|28'), [28, 12]);
    expect(parseGenreIds('SF,드라마'), isEmpty); // 4주차 이름 값은 버린다
    expect(parseGenreIds(null), isEmpty);
  });

  group('TmdbMovieService 요청 모양', () {
    late RecordingAdapter adapter;
    late TmdbMovieService service;

    setUp(() {
      adapter = RecordingAdapter((options) {
        if (options.path == '/genre/movie/list') {
          return (
            200,
            {
              'genres': [
                {'id': 28, 'name': '액션'},
              ],
            },
          );
        }
        return (
          200,
          pageJson([
            {'id': 1, 'title': 'A'},
          ]),
        );
      });
      final dio = createTmdbClient(
        accessToken: 'test-token',
        enableLogging: false,
      )..httpClientAdapter = adapter;
      service = TmdbMovieService(dio);
    });

    test('Bearer Token Header와 Popular Query', () async {
      await service.fetchPopular();
      final request = adapter.requests.single;
      expect(
        request.uri.toString(),
        startsWith('https://api.themoviedb.org/3'),
      );
      expect(request.path, '/movie/popular');
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.queryParameters, {'language': 'ko-KR', 'page': 1});
    });

    test('Discover: 전체는 with_genres 없음, 여러 장르는 OR(|)', () async {
      await service.discoverMovies(page: 1);
      await service.discoverMovies(page: 1, genreIds: const []);
      await service.discoverMovies(page: 2, genreIds: const [28]);
      await service.discoverMovies(page: 1, genreIds: const [28, 12]);
      final queries = adapter.requests.map((r) => r.queryParameters).toList();
      expect(queries[0].containsKey('with_genres'), isFalse);
      expect(queries[1].containsKey('with_genres'), isFalse);
      expect(queries[2]['with_genres'], '28');
      expect(queries[2]['page'], 2);
      expect(queries[3]['with_genres'], '28|12');
      expect(queries[3], containsPair('sort_by', 'popularity.desc'));
      expect(queries[3], containsPair('include_adult', false));
      expect(queries[3], containsPair('include_video', false));
      expect(queries[3], containsPair('language', 'ko-KR'));
    });

    test('Genre API는 language=ko', () async {
      final genres = await service.fetchGenres();
      expect(genres.single.name, '액션');
      expect(adapter.requests.single.queryParameters, {'language': 'ko'});
    });
  });

  test('자체 백엔드 Client는 TMDB Token을 싣지 않고 경로를 인코딩한다', () async {
    final adapter = RecordingAdapter((options) => (200, {'available': true}));
    final dio = createMovieLogApiClient(
      baseUrl: 'http://localhost:3000',
      enableLogging: false,
    )..httpClientAdapter = adapter;
    final service = MovieLogApiService(dio);
    expect((await service.checkNickname('수현')).available, isTrue);
    final request = adapter.requests.single;
    expect(request.headers.containsKey('Authorization'), isFalse);
    expect(request.uri.toString(), contains('/members/nickname/%EC%88%98'));
  });

  group('로그 Interceptor', () {
    test('Authorization 원문을 남기지 않고, 실패 URL·상태를 남긴다', () async {
      final logs = <String>[];
      final dio =
          createTmdbClient(
              accessToken: 'secret-token-123',
              enableLogging: true,
              log: logs.add,
            )
            ..httpClientAdapter = RecordingAdapter(
              (options) => (401, {'status_message': 'Invalid API key'}),
            );
      await expectLater(
        TmdbMovieService(dio).fetchPopular(),
        throwsA(isA<DioException>()),
      );
      final all = logs.join('\n');
      expect(all, isNot(contains('secret-token-123')));
      expect(all, contains('Bearer ***'));
      expect(
        all,
        contains('[TMDB 요청] GET https://api.themoviedb.org/3/movie/popular'),
      );
      expect(
        all,
        contains('[TMDB 오류] https://api.themoviedb.org/3/movie/popular'),
      );
      expect(all, contains('status=401'));
    });

    test('소문자 authorization 도 가린다', () {
      expect(
        TmdbLoggingInterceptor.maskHeaders({'authorization': 'Bearer x'}),
        {'authorization': 'Bearer ***'},
      );
    });

    test('release 모드(로그 끔)면 아무것도 남기지 않는다', () async {
      final logs = <String>[];
      final dio = createTmdbClient(
        accessToken: 't',
        enableLogging: false,
        log: logs.add,
      )..httpClientAdapter = RecordingAdapter((o) => (200, pageJson([])));
      await TmdbMovieService(dio).fetchPopular();
      expect(dio.interceptors.whereType<TmdbLoggingInterceptor>(), isEmpty);
      expect(logs, isEmpty);
    });
  });
}
