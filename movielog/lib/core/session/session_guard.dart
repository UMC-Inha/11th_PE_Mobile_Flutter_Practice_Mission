/// "지금 도착한 응답이 **현재 로그인 세션**의 것인가?"를 판정한다.
///
/// 비동기 요청은 보낼 때의 [generation]과 계정(email)을 기억해 두었다가, 응답이 도착하면
/// [isCurrent]로 지금과 같은지 확인한다. 같은 이메일로 다시 로그인해도 [startSession]이
/// 번호를 올리므로 새 세션이다(이전 세션에서 늦게 온 응답이 새 세션에 섞이지 않는다).
///
/// 이 객체는 상태의 **기준**이 아니다. 인증 상태의 기준은 8주차 AuthViewModel이고,
/// [AuthSessionBridge]가 그 변화를 여기로 전달한다. 화면·ViewModel은 [startSession]·
/// [invalidate]를 부르지 않고 읽기만 한다.
class SessionGuard {
  int _generation = 0;
  String? _accountId;

  int get generation => _generation;

  /// 검증된(내 정보까지 받은) 현재 계정. 로그아웃·확인 전에는 null.
  String? get accountId => _accountId;

  /// 인증 쪽에서 검증된 새 세션을 시작할 때만 부른다. 같은 계정이어도 번호는 올라간다.
  int startSession(String accountId) {
    _accountId = accountId;
    return ++_generation;
  }

  /// 현재 세션을 무효로 만든다(로그아웃·만료·계정 전환 직전).
  void invalidate() {
    _accountId = null;
    _generation++;
  }

  /// 요청을 보낼 때 기억해 둔 [generation]·[accountId]가 지금도 현재 세션인가.
  bool isCurrent(int generation, String accountId) =>
      _generation == generation && _accountId == accountId;
}
