import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/network/log_redaction.dart';
import 'package:movielog/core/network/movielog_api_client.dart';
import 'package:movielog/core/network/tmdb_client.dart';
import 'package:movielog/core/storage/token_storage.dart';

import 'support.dart';

const _base = 'http://localhost:3000';
const _jwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzIn0.c2lnbmF0dXJlLXBhcnQ';

void main() {
  late FakeTokenStorage storage;
  late StubAdapter adapter;
  late Dio auth;

  setUp(() {
    storage = FakeTokenStorage(token: _jwt);
    adapter = StubAdapter();
    auth = createAuthMovieLogApiClient(
      storage,
      baseUrl: _base,
      enableLogging: false,
    )..httpClientAdapter = adapter;
  });

  String? sentAuthorization(int index) =>
      adapter.requests[index].headers['Authorization'] as String?;

  group('AuthInterceptor: 보호 경로에만 Bearer를 붙인다', () {
    test('내 정보·평점 등록·수정·삭제에는 토큰을 붙인다', () async {
      await auth.get<Object?>('/members/me');
      await auth.patch<Object?>('/members/me', data: {'nickname': '케빈'});
      await auth.post<Object?>('/ratings', data: {'movieId': 550, 'score': 4});
      await auth.patch<Object?>('/ratings/7', data: {'score': 3});
      await auth.delete<Object?>('/ratings/7');

      for (var i = 0; i < 5; i++) {
        expect(sentAuthorization(i), 'Bearer $_jwt', reason: '요청 $i');
      }
    });

    test('9주차 보호 경로: 즐겨찾기 등록·목록·여부·해제, 영화 기록 저장에도 토큰을 붙인다', () async {
      await auth.post<Object?>('/favorites', data: {'movieId': 550});
      await auth.get<Object?>('/favorites');
      await auth.get<Object?>('/favorites/550');
      await auth.delete<Object?>('/favorites/550');
      await auth.post<Object?>(
        '/movie-records',
        data: {'movieId': 550, 'score': 4, 'addToFavorites': true},
      );

      expect(adapter.requests, hasLength(5));
      for (var i = 0; i < 5; i++) {
        expect(
          sentAuthorization(i),
          'Bearer $_jwt',
          reason: '${adapter.requests[i].method} ${adapter.requests[i].path}',
        );
      }
    });

    test('9주차 보호 경로와 비슷한 경로(/favoritesx, /movie-records/1)에는 붙이지 않는다', () async {
      await auth.get<Object?>('/favoritesx');
      await auth.get<Object?>('/favorite');
      await auth.get<Object?>('/movie-records/1');
      await auth.get<Object?>('/movie-recordsx');
      for (var i = 0; i < adapter.requests.length; i++) {
        expect(sentAuthorization(i), isNull, reason: adapter.requests[i].path);
      }
    });

    test('9주차 보호 경로라도 TMDB·외부 URL로 가는 요청에는 붙이지 않는다', () async {
      await auth.get<Object?>('https://api.themoviedb.org/3/favorites');
      await auth.get<Object?>('http://evil.example/favorites/550');
      await auth.post<Object?>('http://localhost:3001/favorites');
      await auth.post<Object?>('https://evil.example/movie-records');
      for (var i = 0; i < adapter.requests.length; i++) {
        expect(
          sentAuthorization(i),
          isNull,
          reason: '${adapter.requests[i].uri}',
        );
      }
    });

    test('로그인·중복 확인·회원가입·유저별 평점 조회(공개)에는 붙이지 않는다', () async {
      await auth.post<Object?>('/auth/login', data: {'email': 'a@b.com'});
      await auth.get<Object?>('/members/nickname/케빈');
      await auth.get<Object?>('/members/email/a@b.com');
      await auth.post<Object?>('/members', data: {});
      await auth.get<Object?>('/members/1/ratings');

      for (var i = 0; i < adapter.requests.length; i++) {
        expect(sentAuthorization(i), isNull, reason: adapter.requests[i].path);
      }
      expect(storage.reads, 0, reason: '공개 요청은 저장소를 읽지도 않는다');
    });

    test('비슷하게 생긴 경로(/ratingsx, /members/me/x)에도 붙이지 않는다', () async {
      await auth.get<Object?>('/ratingsx');
      await auth.get<Object?>('/members/me/other');
      for (var i = 0; i < adapter.requests.length; i++) {
        expect(sentAuthorization(i), isNull);
      }
    });

    test('다른 host·port로 가는 요청에는 보호 경로여도 붙이지 않는다(외부 URL로 토큰이 새지 않는다)', () async {
      await auth.get<Object?>('http://evil.example/ratings');
      await auth.get<Object?>('http://localhost:3001/members/me'); // 다른 port
      await auth.get<Object?>('https://api.themoviedb.org/3/members/me');
      await auth.get<Object?>('https://image.tmdb.org/t/p/w500/ratings/1.jpg');

      for (var i = 0; i < adapter.requests.length; i++) {
        expect(
          sentAuthorization(i),
          isNull,
          reason: '${adapter.requests[i].uri}',
        );
      }
    });

    test('서버 주소에 경로 접두사가 있어도(…/api) 그 아래의 보호 경로를 알아본다', () async {
      final prefixed = createAuthMovieLogApiClient(
        storage,
        baseUrl: '$_base/api',
        enableLogging: false,
      )..httpClientAdapter = adapter;
      await prefixed.get<Object?>('/members/me');
      await prefixed.get<Object?>('/members/1/ratings');
      expect(sentAuthorization(0), 'Bearer $_jwt');
      expect(sentAuthorization(1), isNull);
    });

    test('미리 들어 있던 Authorization은 먼저 지우고 저장소의 토큰으로 바꾼다', () async {
      await auth.get<Object?>(
        '/members/me',
        options: Options(headers: {'Authorization': 'Bearer old-token'}),
      );
      expect(sentAuthorization(0), 'Bearer $_jwt');
    });

    test('저장된 토큰이 없으면 이전 헤더도 남기지 않고 그대로 보낸다(서버가 401로 답한다)', () async {
      storage.token = null;
      await auth.get<Object?>(
        '/members/me',
        options: Options(headers: {'Authorization': 'Bearer old-token'}),
      );
      expect(sentAuthorization(0), isNull);
      expect(adapter.requests, hasLength(1));
    });

    test('저장소를 읽지 못하면 요청을 보내지 않고 unknown 오류로 멈춘다(401이 아니다)', () async {
      storage.failRead = true;
      await expectLater(
        auth.get<Object?>('/members/me'),
        throwsA(
          isA<DioException>()
              .having((e) => e.type, 'type', DioExceptionType.unknown)
              .having((e) => e.error, 'error', isA<StateError>())
              .having((e) => e.response, 'response', isNull),
        ),
      );
      expect(adapter.requests, isEmpty);
    });
  });

  group('TMDB Token과 MovieLog JWT는 서로 다른 Client에만 간다', () {
    test('TMDB Client는 TMDB Token만 싣고 MovieLog JWT는 절대 싣지 않는다', () async {
      final tmdbAdapter = StubAdapter();
      final tmdb = createTmdbClient(
        accessToken: 'tmdb-read-token',
        enableLogging: false,
      )..httpClientAdapter = tmdbAdapter;
      await tmdb.get<Object?>('/movie/popular');
      // 같은 앱에 로그인 토큰이 저장돼 있어도 TMDB 요청에는 실리지 않는다.
      expect(storage.token, _jwt);
      final sent = tmdbAdapter.requests.single;
      expect(sent.headers['Authorization'], 'Bearer tmdb-read-token');
      expect('${sent.headers}', isNot(contains(_jwt)));
      expect(sent.uri.host, 'api.themoviedb.org');
    });

    test('TMDB 주소를 바꿔 끼워도(.env 지정) 그 Client에는 MovieLog JWT가 실리지 않는다', () async {
      final tmdbAdapter = StubAdapter();
      final tmdb = createTmdbClient(
        accessToken: 'tmdb-read-token',
        baseUrl: 'http://localhost:3300',
        enableLogging: false,
      )..httpClientAdapter = tmdbAdapter;
      await tmdb.get<Object?>('/members/me'); // 보호 경로 모양이어도
      await tmdb.get<Object?>('/ratings');
      await tmdb.get<Object?>('/favorites/550'); // 9주차 보호 경로 모양이어도
      await tmdb.get<Object?>('/movie-records');
      for (final request in tmdbAdapter.requests) {
        expect(request.headers['Authorization'], 'Bearer tmdb-read-token');
        expect('${request.headers}', isNot(contains(_jwt)));
      }
    });

    test('MovieLog 보호 Client는 TMDB Token을 모르고 JWT만 싣는다', () async {
      await auth.get<Object?>('/members/me');
      final headers = '${adapter.requests.single.headers}';
      expect(headers, contains(_jwt));
      expect(headers, isNot(contains('tmdb-read-token')));
    });

    test('MovieLog 공개 Client에는 어떤 Authorization도 없다', () async {
      final publicAdapter = StubAdapter();
      final public = createMovieLogApiClient(
        baseUrl: _base,
        enableLogging: false,
      )..httpClientAdapter = publicAdapter;
      await public.post<Object?>('/auth/login', data: {});
      await public.get<Object?>('/members/me'); // 보호 경로를 실수로 공개 Client로 보내도
      for (final request in publicAdapter.requests) {
        expect(request.headers.containsKey('Authorization'), isFalse);
      }
    });
  });

  group('로그에 토큰·비밀번호 원문이 남지 않는다', () {
    test('로그인 응답의 accessToken과 Authorization 헤더는 가려진다', () async {
      final logs = <String>[];
      final stub = StubAdapter(
        (options) => (
          200,
          {
            'isSuccess': true,
            'code': 'COMMON200',
            'message': '로그인에 성공했습니다.',
            'result': {'nickname': '케빈', 'accessToken': _jwt},
          },
        ),
      );
      final public = createMovieLogApiClient(
        baseUrl: _base,
        enableLogging: true,
        log: logs.add,
      )..httpClientAdapter = stub;
      final protected = createAuthMovieLogApiClient(
        storage,
        baseUrl: _base,
        enableLogging: true,
        log: logs.add,
      )..httpClientAdapter = stub;

      await public.post<Object?>(
        '/auth/login',
        data: {'email': 'kevin@umc.com', 'password': 'Secret1234!'},
      );
      await protected.get<Object?>('/members/me');

      final all = logs.join('\n');
      expect(all, contains('POST'));
      expect(all, contains('/auth/login'));
      expect(all, contains('케빈')); // 일반 값은 남는다
      expect(all, contains('Bearer ***'));
      expect(all, isNot(contains(_jwt)));
      expect(all, isNot(contains('eyJ')));
      expect(all, isNot(contains('Secret1234!')));
    });

    test('9주차 즐겨찾기·영화 기록 요청의 로그에도 JWT 원문이 없다(Bearer ***만 남는다)', () async {
      final logs = <String>[];
      final stub = StubAdapter(
        (options) => (
          200,
          {
            'isSuccess': true,
            'code': 'COMMON200',
            'message': 'ok',
            'result': {'isFavorite': true},
          },
        ),
      );
      final protected = createAuthMovieLogApiClient(
        storage,
        baseUrl: _base,
        enableLogging: true,
        log: logs.add,
      )..httpClientAdapter = stub;
      await protected.post<Object?>('/favorites', data: {'movieId': 550});
      await protected.get<Object?>('/favorites/550');
      await protected.delete<Object?>('/favorites/550');
      await protected.post<Object?>(
        '/movie-records',
        data: {'movieId': 550, 'score': 4, 'addToFavorites': true},
      );
      final all = logs.join('\n');
      expect(all, contains('/favorites/550'));
      expect(all, contains('/movie-records'));
      expect(all, contains('Bearer ***'));
      expect(all, isNot(contains(_jwt)));
      expect(all, isNot(contains('eyJ')));
    });

    test('JWT 모양이 아닌 값도 민감한 키(accessToken·password·token)면 가린다', () async {
      final logs = <String>[];
      final stub = StubAdapter(
        (options) => (
          200,
          {
            'isSuccess': true,
            'code': 'COMMON200',
            'message': 'ok',
            'result': {
              'nickname': '케빈',
              'accessToken': 'opaque-access-value',
              'Password': 'echoed-secret-value',
              'nested': [
                {'token': 'opaque-token-value', 'AUTHORIZATION': 'opaque-auth'},
              ],
            },
          },
        ),
      );
      final protected = createAuthMovieLogApiClient(
        storage,
        baseUrl: _base,
        enableLogging: true,
        log: logs.add,
      )..httpClientAdapter = stub;

      await protected.get<Object?>('/members/me');

      final all = logs.join('\n');
      expect(all, contains('케빈'));
      for (final secret in [
        'opaque-access-value',
        'echoed-secret-value',
        'opaque-token-value',
        'opaque-auth',
      ]) {
        expect(all, isNot(contains(secret)), reason: secret);
      }
    });

    test(
      'redactSensitive: 키는 대소문자 구분 없이, 중첩 Map·List 안까지 가리고 일반 값은 그대로 둔다',
      () {
        final redacted = redactSensitive({
          'nickname': '케빈',
          'AccessToken': 'a',
          'list': [
            {'PASSWORD': 'b', 'score': 5},
            'plain',
          ],
        });
        expect(redacted, {
          'nickname': '케빈',
          'AccessToken': '***',
          'list': [
            {'PASSWORD': '***', 'score': 5},
            'plain',
          ],
        });
        // 키로 못 거른 문자열 속 JWT도 마지막 방어선에서 가린다.
        expect(
          redactSensitive({'message': '토큰 $_jwt 입니다'}).toString(),
          isNot(contains(_jwt)),
        );
      },
    );

    test('실패 응답 본문과 오류 메시지에 섞인 토큰도 가린다', () async {
      final logs = <String>[];
      final stub = StubAdapter(
        (options) => (
          401,
          {
            'isSuccess': false,
            'code': 'AUTH401_3',
            'message': '유효하지 않은 토큰입니다. $_jwt',
            'result': {'token': _jwt},
          },
        ),
      );
      final protected = createAuthMovieLogApiClient(
        storage,
        baseUrl: _base,
        enableLogging: true,
        log: logs.add,
      )..httpClientAdapter = stub;

      await expectLater(
        protected.get<Object?>('/members/me'),
        throwsA(isA<DioException>()),
      );
      final all = logs.join('\n');
      expect(all, contains('status=401'));
      expect(all, contains('AUTH401_3'));
      expect(all, isNot(contains(_jwt)));
      expect(all, isNot(contains('eyJ')));
    });
  });

  group('SecureTokenStorage', () {
    test('토큰을 쓰고 읽고 지운다(같은 키 한 곳)', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final storage = SecureTokenStorage(const FlutterSecureStorage());
      expect(await storage.readAccessToken(), isNull);

      await storage.saveAccessToken(_jwt);
      expect(await storage.readAccessToken(), _jwt);

      await storage.deleteAccessToken();
      expect(await storage.readAccessToken(), isNull);
    });

    test('저장 키는 movielog.access_token 하나다', () async {
      FlutterSecureStorage.setMockInitialValues({
        'movielog.access_token': 'seeded',
      });
      final storage = SecureTokenStorage(const FlutterSecureStorage());
      expect(await storage.readAccessToken(), 'seeded');
      expect(SecureTokenStorage.accessTokenKey, 'movielog.access_token');
    });

    test('다시 저장하면 이전 토큰을 덮어쓴다(회원 전환)', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final storage = SecureTokenStorage(const FlutterSecureStorage());
      await storage.saveAccessToken('first');
      await storage.saveAccessToken('second');
      expect(await storage.readAccessToken(), 'second');
    });
  });
}
