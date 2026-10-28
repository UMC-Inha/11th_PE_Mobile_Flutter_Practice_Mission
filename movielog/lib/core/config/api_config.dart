import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// MovieLog Spring 서버 접속 설정입니다.
abstract final class ApiConfig {
  /// 로그인 기능이 아직 없어서 1번 회원을 내 계정으로 사용합니다.
  static const myMemberId = 1;

  /// `.env`의 API_BASE_URL을 우선 사용하고, 없으면 실행 환경에 맞는 주소를 사용합니다.
  /// 앱 안의 localhost는 PC가 아니라 기기 자신을 가리키므로
  /// 안드로이드 에뮬레이터는 PC를 뜻하는 10.0.2.2로 접속합니다.
  static String get baseUrl {
    final fromEnv = dotenv.env['API_BASE_URL'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8081';
    }
    return 'http://localhost:8081';
  }
}
