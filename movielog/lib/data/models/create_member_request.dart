/// POST /members 요청 Body. Dart 객체를 JSON Map으로 바꾸는 방향(toJson)이다.
class CreateMemberRequest {
  const CreateMemberRequest({
    required this.email,
    required this.password,
    required this.nickname,
  });

  final String email;
  final String password;
  final String nickname;

  /// 이메일·닉네임의 앞뒤 공백은 입력 실수라 지운다. 비밀번호는 사용자가 입력한 문자가
  /// 모두 의미 있으므로 trim하지 않고 그대로 보낸다.
  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'password': password,
    'nickname': nickname.trim(),
  };

  /// 로그·오류 출력에 이 객체가 섞여도 비밀번호가 나가지 않게 한다.
  @override
  String toString() =>
      'CreateMemberRequest(email: ${email.trim()}, nickname: ${nickname.trim()})';
}
