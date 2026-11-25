import 'package:shared_preferences/shared_preferences.dart';

/// 로그인 화면의 "이메일 저장" 체크박스가 쓰는 저장소.
///
/// shared_preferences는 일반(평문) 저장소라 **이메일만** 둔다. 비밀번호와 토큰은
/// 절대 여기에 넣지 않는다(토큰은 [TokenStorage]의 보안 저장소 몫이다).
abstract interface class EmailPreference {
  Future<String?> read();
  Future<void> save(String email);
  Future<void> clear();
}

class SharedEmailPreference implements EmailPreference {
  SharedEmailPreference({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const emailKey = 'saved_login_email';
  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() => _preferences.getString(emailKey);

  @override
  Future<void> save(String email) => _preferences.setString(emailKey, email);

  @override
  Future<void> clear() => _preferences.remove(emailKey);
}
