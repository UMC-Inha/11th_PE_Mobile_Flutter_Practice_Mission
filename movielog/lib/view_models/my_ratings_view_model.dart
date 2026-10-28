import 'package:flutter/foundation.dart';
import 'package:movielog/data/models/movielog_dtos.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/movielog_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/load_error_message.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

/// 마이페이지 "내가 남긴 평점".
///
/// 평점(점수·코멘트·movieId)은 자체 백엔드 `GET /members/{memberId}/ratings`에서,
/// 제목·포스터는 그 movieId로 TMDB에서 가져온다. 로그인(7주차) 전이라 회원 ID는 고정값이다.
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._api, this._tmdb, {this.memberId = demoMemberId});

  /// 시드 데이터의 1번 회원(수현). 7주차 로그인 후 토큰의 회원으로 바뀐다.
  static const demoMemberId = 1;

  final MovieLogApiService _api;
  final TmdbMovieService _tmdb;
  final int memberId;

  List<MemberRatingDto> ratings = const [];

  /// movieId → TMDB 영화. TMDB 조회에 실패한 영화는 비어 있고 화면은 movieId만 보여준다.
  Map<int, TmdbMovieDto> moviesById = const {};
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;

  int _requestVersion = 0;
  bool _disposed = false;

  double? get averageScore {
    if (ratings.isEmpty) return null;
    return ratings.map((r) => r.score).reduce((a, b) => a + b) / ratings.length;
  }

  Future<void> load() async {
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    notifyListeners();

    try {
      final result = await _api.fetchMemberRatings(memberId);
      if (_isStale(version)) return;
      ratings = result;
      status = result.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
    } catch (error) {
      if (_isStale(version)) return;
      status = MyRatingsLoadStatus.error;
      message = loadErrorMessage(
        error,
        fallback: '내 평점을 불러오지 못했어요. 서버가 켜져 있는지 확인해 주세요.',
      );
      notifyListeners();
      return;
    }
    notifyListeners();

    // 같은 영화를 두 번 조회하지 않게 movieId를 모은다.
    final ids = ratings.map((rating) => rating.movieId).toSet();
    final found = <int, TmdbMovieDto>{};
    await Future.wait(
      ids.map((id) async {
        try {
          found[id] = await _tmdb.fetchMovie(id);
        } catch (_) {
          // 평점 목록은 자체 서버 데이터라 TMDB가 실패해도 보여준다.
        }
      }),
    );
    if (_isStale(version)) return;
    moviesById = found;
    notifyListeners();
  }

  bool _isStale(int version) => _disposed || version != _requestVersion;

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
