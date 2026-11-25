import 'package:dio/dio.dart';

import 'auth_interceptor.dart';
import '../storage/token_storage.dart';

BaseOptions _movieLogOptions() {
  return BaseOptions(
    baseUrl: 'https://workbook.devnoco.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  );
}

// 공개 요청용 (6주차 코드 유지): 로그인, 중복 체크 / Interceptor 없음
Dio createMovieLogClient() {
  return Dio(_movieLogOptions());
}

// 보호 요청용 (8주차 추가): 내 정보, 평점 등록/수정/삭제 / Interceptor 등록
Dio createAuthMovieLogClient(TokenStorage storage) {
  final dio = Dio(_movieLogOptions());
  dio.interceptors.add(AuthInterceptor(storage));
  return dio;
}
