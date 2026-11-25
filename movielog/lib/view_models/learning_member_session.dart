import 'package:flutter/foundation.dart';

/// 회원가입 결과의 memberId를 보관하는 학습용 현재 회원 상태입니다.
///
/// 메모리에만 있으므로 앱을 재시작하면 사라집니다.
/// memberId를 알고 있다는 사실은 인증이 아니며, JWT 주차에 토큰 기반 식별로 바뀝니다.
class LearningMemberSession extends ChangeNotifier {
  LearningMemberSession({this.memberId});

  int? memberId;

  void setMemberId(int id) {
    memberId = id;
    notifyListeners();
  }

  void clear() {
    memberId = null;
    notifyListeners();
  }
}
