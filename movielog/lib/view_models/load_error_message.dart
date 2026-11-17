import 'dart:async';

import 'package:dio/dio.dart';

/// 요청 실패를 사람이 읽을 안내 문구로 바꾼다. Token·URL 원문은 화면에 넣지 않는다.
String loadErrorMessage(Object error, {required String fallback}) {
  if (error is TimeoutException) return '응답이 늦어지고 있어요. 다시 시도해 주세요.';
  if (error is! DioException) return fallback;
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
      return '응답이 늦어지고 있어요. 다시 시도해 주세요.';
    case DioExceptionType.connectionError:
      return '네트워크 상태를 확인하고 다시 시도해 주세요.';
    case DioExceptionType.badResponse:
      if (error.response?.statusCode == 401) {
        return 'TMDB 인증에 실패했어요. .env의 Token을 확인해 주세요.';
      }
      return fallback;
    default:
      return fallback;
  }
}

bool isTimeoutError(Object error) {
  if (error is TimeoutException) return true;
  return error is DioException &&
      (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout);
}
