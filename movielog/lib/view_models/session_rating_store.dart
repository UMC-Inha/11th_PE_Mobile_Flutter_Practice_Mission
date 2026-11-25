import 'package:flutter/foundation.dart';

import '../data/models/rating_dto.dart';
import 'auth_view_model.dart';

/// 현재 로그인 세션에서 등록 response로 받은 Rating을 보관합니다.
///
/// v7에는 토큰 기반 "내 평점 목록 GET"이 없고, 로그인·내 정보 응답에 memberId도 없습니다.
/// 그래서 앱 재시작 뒤 기존 내 평점 전체를 복원하지 않고,
/// 이번 세션에서 등록한 평점만 수정·삭제 대상으로 관리합니다.
///
/// 로그아웃·만료·다른 계정 로그인으로 [AuthViewModel.sessionVersion]이 바뀌면 목록을 비웁니다.
class SessionRatingStore extends ChangeNotifier {
  SessionRatingStore(this._auth) : _ownerVersion = _auth.sessionVersion {
    _auth.addListener(_onAuthChanged);
  }

  final AuthViewModel _auth;
  int _ownerVersion;
  final List<RatingDto> _ratings = [];

  /// ratingId 내림차순(최근 등록 순)입니다.
  List<RatingDto> get ratings => List.unmodifiable(_ratings);

  void _onAuthChanged() {
    if (_auth.sessionVersion == _ownerVersion) return;
    _ownerVersion = _auth.sessionVersion;
    if (_ratings.isEmpty) return;
    _ratings.clear();
    notifyListeners();
  }

  /// [sessionVersion]은 요청을 보낼 때의 세션입니다. 이전 세션의 늦은 응답은 버립니다.
  void upsert(RatingDto rating, {required int sessionVersion}) {
    if (sessionVersion != _auth.sessionVersion) return;
    _ratings.removeWhere((r) => r.ratingId == rating.ratingId);
    _ratings.add(rating);
    _ratings.sort((a, b) => b.ratingId.compareTo(a.ratingId));
    notifyListeners();
  }

  void remove(int ratingId, {required int sessionVersion}) {
    if (sessionVersion != _auth.sessionVersion) return;
    final before = _ratings.length;
    _ratings.removeWhere((r) => r.ratingId == ratingId);
    if (_ratings.length != before) notifyListeners();
  }


  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
