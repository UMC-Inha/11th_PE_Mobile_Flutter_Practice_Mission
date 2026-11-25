import 'package:flutter/foundation.dart';

/// 학습용 현재 회원. 회원가입 성공 응답의 `memberId`를 앱 안에서만 들고 있다가
/// 영화 상세(평점 등록)와 마이페이지(평점 조회·수정·삭제) Route가 같은 값을 읽는다.
///
/// 이것은 로그인(인증)이 아니다. memberId만 알면 누구든 그 번호로 요청할 수 있고,
/// 앱을 다시 시작하면 사라진다. 로그인 주차에는 이 값 대신 서버가 토큰으로 회원을 식별한다.
class LearningMemberSession extends ChangeNotifier {
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
