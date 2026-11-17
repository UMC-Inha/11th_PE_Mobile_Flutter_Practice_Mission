import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/core/config/tmdb_config.dart';
import 'package:movielog/core/network/tmdb_logging_interceptor.dart';

/// TMDB 전용 Dio Client.
///
/// TMDB는 Bearer Token, MovieLog 자체 API는 이후 주차의 JWT로 인증 방식이 다르다.
/// 그래서 Client를 둘로 나누고 이 Client에는 TMDB Token만 싣는다.
/// [accessToken]은 테스트나 401 재현(잘못된 Token)용으로만 바꿔 넣는다.
Dio createTmdbClient({
  String? accessToken,
  bool enableLogging = kDebugMode,
  void Function(String)? log,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.themoviedb.org/3',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Authorization': 'Bearer ${accessToken ?? TmdbConfig.accessToken}',
        'accept': 'application/json',
      },
    ),
  );

  // 로그는 개발 중 확인 용도. release 모드(kDebugMode=false)에서는 붙이지 않는다.
  if (enableLogging) {
    dio.interceptors.add(TmdbLoggingInterceptor(log: log));
  }
  return dio;
}
