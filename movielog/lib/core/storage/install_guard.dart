import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// (심화) iOS 재설치 뒤 Keychain에 남은 이전 설치의 토큰을 정리합니다.
///
/// 1. `movielog.install_initialized` flag를 읽습니다.
/// 2. flag가 없으면 secure storage에 남아 있던 정보를 모두 삭제합니다.
/// 3. 삭제에 성공한 뒤에만 flag를 true로 기록합니다.
///
/// 보안 인증 수단도 완벽한 재설치 감지기도 아닙니다. 백업·복원 상황에 따라 달라질 수 있습니다.
Future<void> clearSecureStorageOnFirstLaunch({
  SharedPreferencesAsync? preferences,
  FlutterSecureStorage storage = const FlutterSecureStorage(),
}) async {
  const installKey = 'movielog.install_initialized';
  final prefs = preferences ?? SharedPreferencesAsync();
  if (await prefs.getBool(installKey) == true) return;
  await storage.deleteAll();
  await prefs.setBool(installKey, true);
}
