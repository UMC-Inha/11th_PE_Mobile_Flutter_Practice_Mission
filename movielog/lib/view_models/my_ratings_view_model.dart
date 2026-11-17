import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/data/models/rating_with_movie.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/movielog_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/load_error_message.dart';

/// 6주차 조회 대상. 인증된 "내 계정"이 아니라 시드 데이터의 1번 회원(수현)이다.
/// 화면에 입력창을 두지 않고 상수로 관리한다. 7주차 로그인 후 토큰의 회원으로 바뀐다.
const int sampleMemberId = 1;

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

/// "내가 등록한 평점" 화면 ViewModel.
///
/// 평점(점수·후기·movieId)은 자체 백엔드 `GET /members/{memberId}/ratings`에서,
/// 제목·포스터는 그 movieId로 TMDB에서 가져와 [RatingWithMovie]로 묶는다.
/// - 평점이 0개(빈 배열)인 것은 [MyRatingsLoadStatus.empty], 요청 실패는 error로 구분한다.
/// - TMDB 영화 조회가 실패해도 평점 목록은 지우지 않는다(그 영화만 placeholder).
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._api, this._tmdb, {this.memberId = sampleMemberId});

  final MovieLogApiService _api;
  final TmdbMovieService _tmdb;
  final int memberId;

  /// 같은 movieId는 한 번만 조회한다. TMDB가 404를 준 영화는 null로 캐시해 다시 묻지 않고,
  /// 일시적인 네트워크 실패는 캐시하지 않아 다음 load에서 다시 시도한다.
  final Map<int, TmdbMovieDto?> _movieCache = {};

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;

  /// error일 때 오류 문구, success일 때 일부 영화 정보를 못 가져왔다는 안내(없으면 null).
  String? message;

  int _requestVersion = 0;
  bool _disposed = false;

  double? get averageScore {
    if (ratings.isEmpty) return null;
    final total = ratings.fold<int>(
      0,
      (sum, entry) => sum + entry.rating.score,
    );
    return total / ratings.length;
  }

  Future<void> load() async {
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    notifyListeners();

    try {
      final rawRatings = await _api.fetchMemberRatings(memberId);
      if (_isStale(version)) return;

      // 같은 영화를 두 번 조회하지 않게 아직 모르는 movieId만 모아 한꺼번에 묻는다.
      final unknownIds = rawRatings
          .map((rating) => rating.movieId)
          .where((id) => !_movieCache.containsKey(id))
          .toSet();
      await Future.wait(unknownIds.map(_lookupMovie));
      if (_isStale(version)) return;

      var missingMovies = 0;
      final entries = <RatingWithMovie>[];
      for (final rating in rawRatings) {
        final movie = _movieCache[rating.movieId];
        if (movie == null) missingMovies++;
        entries.add(RatingWithMovie(rating: rating, movie: movie));
      }

      ratings = entries;
      status = entries.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
      if (missingMovies > 0) {
        message = '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.';
      }
    } catch (error) {
      if (_isStale(version)) return;
      status = MyRatingsLoadStatus.error;
      message = myRatingsErrorMessage(error);
    }
    notifyListeners();
  }

  Future<void> _lookupMovie(int movieId) async {
    try {
      _movieCache[movieId] = await _tmdb.findMovieById(movieId);
    } catch (_) {
      // 일시적 실패는 캐시하지 않는다. 평점 목록은 그대로 보여주고 다음 load에서 다시 시도한다.
    }
  }

  bool _isStale(int version) => _disposed || version != _requestVersion;

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}

/// 평점 조회 실패를 원인별 문구로 바꾼다. 400(형식 오류)·404(없는 회원)·그 밖의 통신 실패를
/// 하나의 "실패"로 뭉치지 않는다. 평점이 없는 회원은 200 `[]`라서 여기에 오지 않는다.
String myRatingsErrorMessage(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == 400) return 'memberId 형식을 다시 확인해 주세요.';
    if (status == 404) return '존재하지 않는 회원입니다.';
  }
  return loadErrorMessage(
    error,
    fallback: '평점을 불러오지 못했어요. 서버가 켜져 있는지 확인해 주세요.',
  );
}
