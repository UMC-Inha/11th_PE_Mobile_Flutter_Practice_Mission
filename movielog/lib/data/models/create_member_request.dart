/// `POST /v6/members` 요청 body입니다.
class CreateMemberRequest {
  const CreateMemberRequest({
    required this.email,
    required this.password,
    required this.nickname,
  });

  final String email;
  final String password;
  final String nickname;

  /// 비밀번호는 입력한 문자 그대로 보냅니다. 앞뒤 공백은 Form validation에서 막습니다.
  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'password': password,
    'nickname': nickname.trim(),
  };
}
