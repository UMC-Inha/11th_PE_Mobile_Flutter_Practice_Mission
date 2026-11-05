import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/core/config/tmdb_config.dart';
import 'package:movielog/core/network/tmdb_logging_interceptor.dart';

/// MovieLog 자체 백엔드(회원·평점) 전용 Client. TMDB Token을 싣지 않는다.
Dio createMovieLogApiClient({
  String? baseUrl,
  bool enableLogging = kDebugMode,
  void Function(String)? log,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? MovieLogApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {'accept': 'application/json'},
    ),
  );
  if (enableLogging) {
    dio.interceptors.add(TmdbLoggingInterceptor(tag: 'MovieLog API', log: log));
  }
  return dio;
}
