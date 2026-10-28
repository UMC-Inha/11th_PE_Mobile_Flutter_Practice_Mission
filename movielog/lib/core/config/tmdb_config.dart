import 'package:flutter_dotenv/flutter_dotenv.dart';

/// `.env` 값을 읽는 코드와 누락 검사를 한곳에 모은다.
/// 여러 파일에서 키 문자열을 반복하지 않게 한다.
abstract final class TmdbConfig {
  static const accessTokenKey = 'TMDB_ACCESS_TOKEN';

  /// TMDB API Read Access Token. 로그·화면에 원문을 남기지 않는다.
  static String get accessToken => readEnv(accessTokenKey);

  static bool get hasAccessToken => accessToken.isNotEmpty;
}

/// MovieLog 자체 백엔드(회원·평점) 주소.
abstract final class MovieLogApiConfig {
  static const baseUrlKey = 'MOVIELOG_API_BASE_URL';
  static const defaultBaseUrl = 'http://localhost:3000';

  static String get baseUrl {
    final value = readEnv(baseUrlKey);
    return value.isEmpty ? defaultBaseUrl : value;
  }
}

/// `dotenv.load()` 전(테스트 등)에도 예외 없이 빈 문자열을 돌려준다.
String readEnv(String key) {
  if (!dotenv.isInitialized) return '';
  return dotenv.env[key]?.trim() ?? '';
}
