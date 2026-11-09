/// 닉네임·이메일 중복 체크 성공 응답 `{ "available": true }`를 표현합니다.
/// v6에서도 이 API의 성공 응답은 공통 Wrapper 없이 오므로 body를 그대로 변환합니다.
/// 오류 응답만 공통 형식(CommonResponse)입니다.
class CheckResult {
  const CheckResult({required this.available});

  final bool available;

  factory CheckResult.fromJson(Map<String, dynamic> json) {
    return CheckResult(available: json['available'] as bool);
  }
}
