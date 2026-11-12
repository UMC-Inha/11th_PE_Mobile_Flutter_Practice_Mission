/// 회원가입 성공 응답 `result`에 담기는 값. 서버 JSON을 Dart 객체로 바꾸는 방향(fromJson)이다.
class SignUpResult {
  const SignUpResult({
    required this.memberId,
    required this.email,
    required this.nickname,
  });

  final int memberId;
  final String email;
  final String nickname;

  factory SignUpResult.fromJson(Map<String, dynamic> json) {
    return SignUpResult(
      memberId: (json['memberId'] as num).toInt(),
      email: json['email'] as String,
      nickname: json['nickname'] as String,
    );
  }
}
