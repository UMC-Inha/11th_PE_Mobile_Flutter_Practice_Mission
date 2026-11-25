import 'package:dio/dio.dart';
import 'package:movielog/core/storage/token_storage.dart';

/// 보호 API에만 `Authorization: Bearer {토큰}`을 붙이는 Interceptor.
///
/// - 붙이는 대상은 "MovieLog 서버의 보호 경로"뿐이다(host·port와 경로를 함께 본다).
///   TMDB나 외부 이미지 URL 같은 다른 곳에는 절대 토큰을 보내지 않는다.
/// - 로그인·중복 확인처럼 토큰이 필요 없는 요청은 건드리지 않는다.
/// - 요청에 미리 들어 있던 Authorization은 먼저 지운다(이전 요청의 토큰 재사용 방지).
/// - 저장소를 읽지 못하면 401처럼 보이지 않게 unknown 오류로 중단한다.
///   서버가 거절한 것(401)과 기기 저장소 문제는 서로 다른 일이다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage, {required String baseUrl})
    : _base = Uri.parse(baseUrl);

  final TokenStorage _storage;
  final Uri _base;

  /// 보호 대상 경로.
  /// - 정확히 일치: 내 정보, 평점 등록, 즐겨찾기 등록·목록, 영화 기록 저장
  /// - 접두사: `/ratings/{id}`, `/favorites/{movieId}`처럼 뒤에 붙는 경로
  ///
  /// 이 서버에는 `/v7`·`/v8` 접두사가 없어 워크북의 `/v8/...` 대신 접두사 없는 경로를 쓴다.
  static const protectedExactPaths = {
    '/members/me',
    '/ratings',
    '/favorites',
    '/movie-records',
  };
  static const protectedPrefixes = ['/ratings/', '/favorites/'];

  bool isProtected(RequestOptions options) {
    final uri = options.uri;
    if (uri.scheme != _base.scheme ||
        uri.host != _base.host ||
        uri.port != _base.port) {
      return false;
    }
    var basePath = _base.path;
    if (basePath.endsWith('/')) {
      basePath = basePath.substring(0, basePath.length - 1);
    }
    if (!uri.path.startsWith(basePath)) return false;
    final path = uri.path.substring(basePath.length);
    return protectedExactPaths.contains(path) ||
        protectedPrefixes.any(path.startsWith);
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!isProtected(options)) {
      handler.next(options);
      return;
    }
    options.headers.remove('Authorization');
    try {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    } catch (_) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: StateError('인증 저장소를 읽지 못했습니다.'),
        ),
      );
    }
  }
}
