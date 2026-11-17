/// 자체 백엔드의 공통 응답 틀 `{ isSuccess, code, message, result }`.
///
/// 회원가입·평점 등록 성공 응답과 모든 API의 실패 응답이 이 틀을 쓴다.
/// result는 API마다 담기는 값이 달라 제네릭 T로 표현하고, 값이 없거나 실패 응답이면 null이다.
/// (닉네임·이메일 확인, 평점 조회의 성공 본문은 예전 모양 그대로라 이 틀을 쓰지 않는다.)
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
}
