import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Access Token을 저장·조회·삭제하는 규칙을 인증 흐름에서 분리한 추상화.
///
/// 로그인·로그아웃·요청 인증 코드가 FlutterSecureStorage 같은 구체적인 저장소에
/// 직접 기대지 않게 하므로, 테스트에서는 메모리 저장소로 바꿔 끼울 수 있다.
abstract interface class TokenStorage {
  Future<void> saveAccessToken(String token);
  Future<String?> readAccessToken();
  Future<void> deleteAccessToken();
}

/// 운영체제의 보안 저장 영역(iOS Keychain·Android Keystore)에 토큰을 둔다.
/// SharedPreferences 같은 일반 key-value 저장소는 값을 평문으로 저장해 기기 분석이나
/// 백업 추출 과정에서 토큰이 노출될 수 있어서 쓰지 않는다.
///
/// 주의: Flutter Web에서는 이 플러그인이 Keychain/Keystore가 아니라 브라우저 저장소 위에서
/// 동작한다. 모바일의 보안 수준을 웹에서 확인한 것으로 말하지 않는다.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage(this._storage);

  static const accessTokenKey = 'movielog.access_token';
  final FlutterSecureStorage _storage;

  @override
  Future<void> saveAccessToken(String token) =>
      _storage.write(key: accessTokenKey, value: token);

  @override
  Future<String?> readAccessToken() => _storage.read(key: accessTokenKey);

  @override
  Future<void> deleteAccessToken() => _storage.delete(key: accessTokenKey);
}
