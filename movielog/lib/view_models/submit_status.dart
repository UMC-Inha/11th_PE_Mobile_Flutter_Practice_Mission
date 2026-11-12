/// 쓰기 요청(회원가입·평점 등록) 한 번의 진행 상태.
/// 조회 화면의 로딩 상태와 달리 "버튼을 누른 뒤"의 상태라, 요청 중 중복 탭·이탈을 막는 데 쓴다.
enum SubmitStatus { idle, submitting, success, error }

/// 평점 저장 Dialog가 실패 사유를 사용자에게 그대로 보여주기 위한 예외.
/// [message]에는 서버가 내려 준 안내 문장이 들어 있다.
class RatingSaveException implements Exception {
  const RatingSaveException(this.message);

  final String message;

  @override
  String toString() => message;
}
