/// POST /auth/login 요청 Body.
class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  /// 이메일의 앞뒤 공백은 입력 실수라 지운다. 비밀번호는 입력한 문자가 모두 의미 있어 그대로 둔다.
  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'password': password,
  };

  /// 로그·오류 출력에 섞여도 비밀번호가 나가지 않게 뺀다.
  @override
  String toString() => 'LoginRequest(email: ${email.trim()})';
}

/// 로그인 성공 응답의 `result`. **memberId는 없다.** 서버 명세에 없는 필드나 JWT의 claim을
/// 추정해서 읽지 않는다.
class LoginResult {
  const LoginResult({required this.nickname, required this.accessToken});

  final String nickname;
  final String accessToken;

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      nickname: json['nickname'] as String,
      accessToken: json['accessToken'] as String,
    );
  }

  /// 토큰 원문이 로그·오류 메시지에 섞이지 않게 가린다.
  @override
  String toString() => 'LoginResult(nickname: $nickname, accessToken: ***)';
}
