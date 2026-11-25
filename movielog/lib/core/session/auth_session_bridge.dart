import 'package:flutter/foundation.dart';
import 'package:movielog/core/session/session_guard.dart';

/// AuthViewModel의 상태 변화를 [SessionGuard]에 전달하는 연결부.
///
/// 인증 상태의 기준은 AuthViewModel이 그대로 갖는다. 이 클래스는 둘의 값
/// (sessionVersion, 검증된 email)이 **바뀌었을 때만** guard를 새로 시작한다.
/// 닉네임 수정·안내 문구 변경처럼 값이 그대로인 알림에서는 아무것도 하지 않는다.
class AuthSessionBridge {
  AuthSessionBridge({
    required this.authSignals,
    required this.sessionVersion,
    required this.verifiedEmail,
  }) {
    authSignals.addListener(_sync);
    _sync();
  }

  /// 인증 상태가 바뀔 때 알려 주는 Listenable(AuthViewModel).
  final Listenable authSignals;

  /// 로그인·복원·정리가 시작될 때마다 올라가는 번호.
  final int Function() sessionVersion;

  /// signedIn이고 내 정보 조회까지 끝나 member가 생기기 전에는 null.
  final String? Function() verifiedEmail;

  final SessionGuard guard = SessionGuard();
  int? _seenVersion;
  String? _seenEmail;
  bool _disposed = false;

  void _sync() {
    if (_disposed) return;
    final version = sessionVersion();
    final email = verifiedEmail();
    if (version == _seenVersion && email == _seenEmail) return;
    _seenVersion = version;
    _seenEmail = email;
    guard.invalidate();
    if (email != null) guard.startSession(email);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    authSignals.removeListener(_sync);
    guard.invalidate();
  }
}
