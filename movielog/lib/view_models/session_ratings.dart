import 'package:flutter/foundation.dart';
import 'package:movielog/data/models/movielog_dtos.dart';
import 'package:movielog/view_models/auth_view_model.dart';

/// **이번 로그인 세션에서** 등록한 평점을 메모리에 들고 있는 저장소.
///
/// 서버에는 "토큰으로 내 평점 목록을 읽는" API가 없고, 로그인·내 정보 응답에도 memberId가 없다
/// (JWT claim을 추정하지 않는다). 그래서 평점 등록·수정 응답으로 받은 평점 객체를 여기에 모아
/// 마이페이지에서 수정·삭제한다. 앱을 다시 켜면 비어 있고, 이는 서버 계약상의 한계다.
///
/// 세션이 바뀌면(로그아웃·만료·다른 계정 로그인·앱 재시작) 비운다. 이전 세션에서 늦게 도착한
/// 응답이 새 세션의 목록에 섞이지 않게, 쓰기 메서드는 요청을 **보낼 때**의 sessionVersion을 받아
/// 지금과 다르면 무시한다.
class SessionRatings extends ChangeNotifier {
  SessionRatings(this._auth) {
    _version = _auth.sessionVersion;
    _auth.addListener(_onAuthChanged);
  }

  final AuthViewModel _auth;
  int _version = 0;
  List<MemberRatingDto> _ratings = const [];
  bool _disposed = false;

  /// 새로 등록한 것이 위로 오는 순서.
  List<MemberRatingDto> get ratings => _ratings;

  void _onAuthChanged() {
    if (_auth.sessionVersion == _version && _auth.isSignedIn) return;
    _version = _auth.sessionVersion;
    if (_ratings.isNotEmpty) {
      _ratings = const [];
      if (!_disposed) notifyListeners();
    }
  }

  bool _accepts(int version) =>
      !_disposed && version == _auth.sessionVersion && _auth.isSignedIn;

  /// 등록 응답으로 받은 평점을 맨 위에 더한다. 같은 ratingId가 있으면 교체한다.
  bool add(MemberRatingDto rating, {required int version}) {
    if (!_accepts(version)) return false;
    _ratings = [
      rating,
      ..._ratings.where((item) => item.ratingId != rating.ratingId),
    ];
    notifyListeners();
    return true;
  }

  /// 수정 응답으로 받은 평점으로 같은 ratingId를 바꾼다(자리는 그대로).
  bool replace(MemberRatingDto rating, {required int version}) {
    if (!_accepts(version)) return false;
    _ratings = [
      for (final item in _ratings)
        if (item.ratingId == rating.ratingId) rating else item,
    ];
    notifyListeners();
    return true;
  }

  bool remove(int ratingId, {required int version}) {
    if (!_accepts(version)) return false;
    _ratings = _ratings.where((item) => item.ratingId != ratingId).toList();
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
