import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Client를 거치는 모든 요청·응답·오류를 같은 형식으로 남긴다.
///
/// - 기록만 한다. 화면 표시·저장은 개발 환경(콘솔, Network Inspector)에 맡긴다.
/// - Authorization 같은 민감한 Header는 원문 대신 `Bearer ***`로 가린다.
/// - [log]를 바꿔 끼우면 테스트에서 로그 문자열을 직접 확인할 수 있다.
class TmdbLoggingInterceptor extends Interceptor {
  TmdbLoggingInterceptor({this.tag = 'TMDB', void Function(String)? log})
    : _log = log ?? ((message) => debugPrint(message));

  final String tag;
  final void Function(String) _log;

  static const _maxBodyLength = 400;

  /// Header 이름은 대소문자를 구분하지 않으므로 `authorization`도 함께 가린다.
  static Map<String, dynamic> maskHeaders(Map<String, dynamic> headers) {
    return headers.map(
      (key, value) => MapEntry(
        key,
        key.toLowerCase() == 'authorization' ? 'Bearer ***' : value,
      ),
    );
  }

  static String _shorten(Object? body) {
    final text = '$body';
    if (text.length <= _maxBodyLength) return text;
    return '${text.substring(0, _maxBodyLength)}… (${text.length}자 중 앞부분)';
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _log('[$tag 요청] ${options.method} ${options.uri}');
    _log('[$tag 요청 Header] ${maskHeaders(options.headers)}');
    if (options.queryParameters.isNotEmpty) {
      _log('[$tag 요청 Query] ${options.queryParameters}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _log('[$tag 응답] ${response.statusCode} ${response.requestOptions.uri}');
    _log('[$tag 응답 Body] ${_shorten(response.data)}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log('[$tag 오류] ${err.requestOptions.uri}');
    _log(
      '[$tag 오류 내용] ${err.type.name} '
      'status=${err.response?.statusCode} ${err.message}',
    );
    if (err.response?.data != null) {
      _log('[$tag 오류 Body] ${_shorten(err.response?.data)}');
    }
    handler.next(err);
  }
}
