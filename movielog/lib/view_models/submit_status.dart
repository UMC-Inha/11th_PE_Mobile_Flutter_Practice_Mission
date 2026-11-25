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

/// 저장은 실패했지만 입력을 고치거나 다시 눌러도 소용없는 경우(이미 평점이 있음·이미 즐겨찾기·회원 없음)에
/// Dialog를 **닫고** 그 사유를 Snackbar로 안내하게 하는 예외. [RatingSaveException]은 Dialog를 열어 둔다.
class RatingSaveClosedException implements Exception {
  const RatingSaveClosedException(this.message);

  final String message;

  @override
  String toString() => message;
}
