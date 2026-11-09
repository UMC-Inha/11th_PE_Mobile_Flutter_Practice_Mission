/// v6 공통 응답 `{ isSuccess, code, message, result }`입니다.
/// 회원가입·평점 등록·수정 성공 응답과 v6의 모든 실패 응답을 이 형식으로 파싱합니다.
class CommonResponse<T> {
  const CommonResponse({
    required this.isSuccess,
    required this.code,
    required this.message,
    this.result,
  });

  final bool isSuccess;
  final String code;
  final String message;

  /// API마다 담기는 값이 다릅니다. 값이 없거나 실패 응답이면 null입니다.
  final T? result;

  factory CommonResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? value) parseResult,
  ) {
    final rawResult = json['result'];
    return CommonResponse<T>(
      isSuccess: json['isSuccess'] as bool,
      code: json['code'] as String,
      message: json['message'] as String,
      result: rawResult == null ? null : parseResult(rawResult),
    );
  }

  /// 오류 응답 body가 공통 형식이면 파싱하고, 아니면 null을 반환합니다.
  static CommonResponse<Object?>? tryParseError(Object? data) {
    if (data is! Map<String, dynamic>) return null;
    try {
      return CommonResponse<Object?>.fromJson(data, (value) => value);
    } on TypeError {
      // 프레임워크 기본 오류처럼 공통 형식이 아닌 body입니다.
      return null;
    }
  }
}
