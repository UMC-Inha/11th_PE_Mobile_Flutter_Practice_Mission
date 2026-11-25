import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/core/network/movielog_api_client.dart';
import 'package:movielog/data/models/favorite_check_dto.dart';
import 'package:movielog/data/models/favorite_response_dto.dart';
import 'package:movielog/data/services/favorite_api_service.dart';

import 'support.dart';

const _base = 'http://localhost:3000';
const _jwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzIn0.c2lnbmF0dXJlLXBhcnQ';

Map<String, Object?> _favoriteJson(int favoriteId, int movieId) => {
  'favoriteId': favoriteId,
  'movieId': movieId,
  'createdAt': '2026-11-20T09:00:00.000Z',
};

Map<String, Object?> _ok(int code, Object? result) => {
  'isSuccess': true,
  'code': 'COMMON$code',
  'message': '성공',
  'result': result,
};

Map<String, Object?> _fail(String code, String message) => {
  'isSuccess': false,
  'code': code,
  'message': message,
  'result': null,
};

void main() {
  late FakeTokenStorage storage;

  setUp(() => storage = FakeTokenStorage(token: _jwt));

  /// 정해 둔 응답을 돌려주는 보호 Client로 만든 [FavoriteApiService].
  (FavoriteApiService, StubAdapter) build((int, Object?) Function(RequestOptions) respond) {
    final adapter = StubAdapter(respond);
    final dio = createAuthMovieLogApiClient(
      storage,
      baseUrl: _base,
      enableLogging: false,
    )..httpClientAdapter = adapter;
    return (FavoriteApiService(dio), adapter);
  }

  group('DTO 파싱', () {
    test('FavoriteResponseDto: favoriteId·movieId·createdAt을 읽는다', () {
      final dto = FavoriteResponseDto.fromJson(_favoriteJson(3, 550));
      expect(dto.favoriteId, 3);
      expect(dto.movieId, 550);
      expect(dto.createdAt, DateTime.utc(2026, 11, 20, 9));
    });

    test('FavoriteResponseDto: 객체가 아니거나 필드가 틀리면 예외', () {
      expect(() => FavoriteResponseDto.fromJson('x'), throwsFormatException);
      expect(
        () => FavoriteResponseDto.fromJson({'favoriteId': 1}),
        throwsA(isA<TypeError>()),
      );
    });

    test('FavoriteCheckDto: 응답에는 movieId가 없어서 요청한 값을 인자로 받는다', () {
      final dto = FavoriteCheckDto.fromJson({
        'isFavorite': true,
      }, movieId: 550);
      expect(dto.isFavorite, isTrue);
      expect(dto.movieId, 550);
    });

    test('FavoriteCheckDto: isFavorite이 bool이 아니면 예외', () {
      expect(
        () => FavoriteCheckDto.fromJson({'isFavorite': 'true'}, movieId: 1),
        throwsFormatException,
      );
      expect(
        () => FavoriteCheckDto.fromJson(null, movieId: 1),
        throwsFormatException,
      );
    });
  });

  group('FavoriteApiService: 요청 모양', () {
    test('등록: POST /favorites, 본문은 movieId 하나뿐(memberId 없음), 201 result를 읽는다', () async {
      final (service, adapter) = build(
        (_) => (201, _ok(201, _favoriteJson(1, 550))),
      );
      final created = await service.addFavorite(movieId: 550);

      expect(created.favoriteId, 1);
      expect(created.movieId, 550);
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/favorites');
      expect(request.data, {'movieId': 550});
      expect(request.uri.toString(), isNot(contains('memberId')));
    });

    test('내 목록: GET /favorites, result 배열을 순서 그대로 읽고 빈 배열은 빈 목록이다', () async {
      var empty = false;
      final (service, adapter) = build(
        (_) => (
          200,
          _ok(200, empty ? [] : [_favoriteJson(2, 603), _favoriteJson(1, 550)]),
        ),
      );
      final list = await service.fetchMyFavorites();
      expect(list.map((f) => f.movieId), [603, 550]);
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, '/favorites');

      empty = true;
      expect(await service.fetchMyFavorites(), isEmpty);
    });

    test('여부 조회: GET /favorites/{movieId}, 응답에 없는 movieId는 요청한 값으로 채운다', () async {
      final (service, adapter) = build(
        (_) => (200, _ok(200, {'isFavorite': false})),
      );
      final check = await service.checkFavorite(movieId: 27205);
      expect(check.isFavorite, isFalse);
      expect(check.movieId, 27205);
      expect(adapter.requests.single.path, '/favorites/27205');
    });

    test('해제: DELETE /favorites/{movieId}는 200 + result null이어도 성공이다(본문을 파싱하지 않는다)', () async {
      final (service, adapter) = build((_) => (200, _ok(200, null)));
      await service.deleteFavorite(movieId: 550);
      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.path, '/favorites/550');
    });

    test('해제: 본문이 비어 있어도(204처럼) DioException이 없으면 성공이다', () async {
      final (service, _) = build((_) => (200, null));
      await service.deleteFavorite(movieId: 550);
    });

    test('네 요청 모두 보호 Client라서 Bearer가 붙는다', () async {
      final (service, adapter) = build((options) {
        if (options.method == 'GET' && options.path == '/favorites') {
          return (200, _ok(200, []));
        }
        if (options.method == 'GET') return (200, _ok(200, {'isFavorite': true}));
        if (options.method == 'POST') {
          return (201, _ok(201, _favoriteJson(1, 550)));
        }
        return (200, _ok(200, null));
      });
      await service.addFavorite(movieId: 550);
      await service.fetchMyFavorites();
      await service.checkFavorite(movieId: 550);
      await service.deleteFavorite(movieId: 550);
      expect(adapter.requests, hasLength(4));
      for (final request in adapter.requests) {
        expect(
          request.headers['Authorization'],
          'Bearer $_jwt',
          reason: '${request.method} ${request.path}',
        );
      }
    });
  });

  group('FavoriteApiService: 오류', () {
    Future<DioException> failureOf(
      Future<Object?> Function(FavoriteApiService service) call,
      int status,
      String code,
    ) async {
      final (service, _) = build((_) => (status, _fail(code, '실패')));
      try {
        await call(service);
      } on DioException catch (error) {
        return error;
      }
      fail('DioException이 나와야 한다');
    }

    test('서버의 오류 code를 DioException 그대로 전달한다(409·404·400·401)', () async {
      final conflict = await failureOf(
        (s) => s.addFavorite(movieId: 550),
        409,
        'FAVORITE409_1',
      );
      expect(apiErrorCode(conflict), 'FAVORITE409_1');
      expect(conflict.response?.statusCode, 409);

      final notFound = await failureOf(
        (s) => s.deleteFavorite(movieId: 550),
        404,
        'FAVORITE404_1',
      );
      expect(apiErrorCode(notFound), 'FAVORITE404_1');

      final bad = await failureOf(
        (s) => s.addFavorite(movieId: 0),
        400,
        'COMMON400',
      );
      expect(apiErrorCode(bad), 'COMMON400');

      final expired = await failureOf(
        (s) => s.fetchMyFavorites(),
        401,
        'AUTH401_3',
      );
      expect(isSessionExpiredCode(apiErrorCode(expired)), isTrue);
    });

    test('성공 응답이라도 틀이 어긋나면 StateError(요청 성공을 지어내지 않는다)', () async {
      final (service, _) = build((_) => (201, 'not-json-object'));
      await expectLater(
        service.addFavorite(movieId: 1),
        throwsA(isA<StateError>()),
      );
      final (service2, _) = build((_) => (201, _ok(201, null)));
      await expectLater(
        service2.addFavorite(movieId: 1),
        throwsA(isA<StateError>()),
      );
      final (service3, _) = build((_) => (200, _ok(200, null)));
      await expectLater(
        service3.checkFavorite(movieId: 1),
        throwsA(isA<StateError>()),
      );
    });

    test('result가 배열이 아니면 형식 오류', () async {
      final (service, _) = build((_) => (200, _ok(200, {'a': 1})));
      await expectLater(
        service.fetchMyFavorites(),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
