import 'package:dio/dio.dart';
import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/write_error_message.dart';

/// 평점 등록·수정·삭제 실패를 한곳에서 처리한다. 보호 API의 오류를 서로 다르게 다룬다.
///
/// - AUTH401_2/3/4: 토큰이 없거나 무효이거나 만료 → 세션을 정리한다(Router가 /login으로 보낸다).
///   요청을 보낼 때의 [version]을 함께 넘겨, 이전 세션의 늦은 401이 새 로그인을 지우지 못하게 한다.
/// - 403: 내 평점이 아님 → 안내만 한다. **로그아웃하지 않는다.** 권한 부족은 만료가 아니다.
/// - 400·404·409: 서버 message를 그대로 안내한다(같은 404도 유저/평점이 달라 문구를 새로 만들지 않는다).
/// - 응답이 없는 통신 실패: 원인 문구. 토큰은 지우지 않는다.
///
/// 돌려주는 값은 화면에 보여줄 문구다.
Future<String> handleRatingError(
  DioException error, {
  required AuthViewModel auth,
  required int version,
}) async {
  final code = apiErrorCode(error);
  if (isSessionExpiredCode(code)) {
    await auth.expireSession(forVersion: version);
    return '로그인이 만료됐어요. 다시 로그인해 주세요.';
  }
  return writeErrorMessage(error);
}

/// 요청이 끝났을 때 아직 같은 로그인 세션인지.
bool isSameSession(AuthViewModel auth, int version) =>
    auth.sessionVersion == version && auth.isSignedIn;

/// 계약에서 벗어난 성공 응답(예: 201이 아닌 등록 응답)이나 파싱 실패일 때의 문구.
const unknownWriteResultMessage = '저장 결과를 확인하지 못했습니다. 잠시 후 다시 확인해 주세요.';
