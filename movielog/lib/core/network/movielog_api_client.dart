import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/core/config/tmdb_config.dart';
import 'package:movielog/core/network/auth_interceptor.dart';
import 'package:movielog/core/network/tmdb_logging_interceptor.dart';
import 'package:movielog/core/storage/token_storage.dart';

BaseOptions _movieLogOptions(String? baseUrl) => BaseOptions(
  baseUrl: baseUrl ?? MovieLogApiConfig.baseUrl,
  connectTimeout: const Duration(seconds: 5),
  receiveTimeout: const Duration(seconds: 5),
  headers: {'accept': 'application/json'},
);

/// MovieLog 자체 백엔드의 **공개** 요청 전용 Client(로그인·회원가입·중복 확인·유저별 평점 조회).
/// TMDB Token은 물론 MovieLog JWT도 싣지 않는다. 인증 Interceptor도 없다.
Dio createMovieLogApiClient({
  String? baseUrl,
  bool enableLogging = kDebugMode,
  void Function(String)? log,
}) {
  final dio = Dio(_movieLogOptions(baseUrl));
  if (enableLogging) {
    dio.interceptors.add(TmdbLoggingInterceptor(tag: 'MovieLog API', log: log));
  }
  return dio;
}

/// MovieLog **보호** 요청 전용 Client(내 정보, 평점 등록·수정·삭제).
/// [AuthInterceptor]가 보호 경로에만 JWT를 붙인다. TMDB Client와는 절대 합치지 않는다.
Dio createAuthMovieLogApiClient(
  TokenStorage storage, {
  String? baseUrl,
  bool enableLogging = kDebugMode,
  void Function(String)? log,
}) {
  final options = _movieLogOptions(baseUrl);
  final dio = Dio(options);
  // 로그 Interceptor보다 먼저 등록해, 로그에는 가려진 Authorization만 보이게 한다.
  dio.interceptors.add(AuthInterceptor(storage, baseUrl: options.baseUrl));
  if (enableLogging) {
    dio.interceptors.add(TmdbLoggingInterceptor(tag: 'MovieLog API', log: log));
  }
  return dio;
}
