import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'auth_view_model.dart';
import 'session_rating_store.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty }

/// "내가 등록한 평점" 화면의 조회·수정·삭제 상태를 관리합니다.
/// 목록은 현재 세션에서 등록 response로 받은 Rating입니다.
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, this._movieService, this._auth, this._store) {
    _store.addListener(load);
  }
  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final AuthViewModel _auth;
  final SessionRatingStore _store;

  /// movieId → TMDB 영화입니다. 같은 movieId는 한 번만 묻고, TMDB에 없는 영화(null)도 저장합니다.
  final Map<int, TmdbMovieDto?> _moviesById = {};
  int _requestVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;

  /// 영화 정보 누락 안내입니다.
  String? message;

  Future<void> load() async {
    if (_disposed) return;
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    notifyListeners();

    bool isStale() => _disposed || version != _requestVersion;

    final entries = <RatingWithMovie>[];
    var missingMovies = 0;
    // 영화 조회 실패가 평점 목록을 지우지 않습니다.
    for (final rating in _store.ratings) {
      if (isStale()) return;
      if (!_moviesById.containsKey(rating.movieId)) {
        try {
          _moviesById[rating.movieId] = await _movieService.findMovieById(
            rating.movieId,
          );
        } on DioException {
          // 일시적 네트워크 실패는 캐시하지 않고 다음 로딩에서 재시도합니다.
        }
      }
      final movie = _moviesById[rating.movieId];
      if (movie == null) missingMovies++;
      entries.add(RatingWithMovie(rating: rating, movie: movie));
    }
    if (isStale()) return;

    ratings = entries;
    status = entries.isEmpty
        ? MyRatingsLoadStatus.empty
        : MyRatingsLoadStatus.success;
    if (missingMovies > 0) {
      message = '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.';
    }
    notifyListeners();
  }

  /// 쓰기 실패를 Dialog가 보여줄 예외로 바꿉니다.
  /// 401은 세션을 정리하고, 403은 안내만 하며, 404는 목록을 새로고침합니다.
  Future<Never> _handleWriteError(
    DioException error,
    int ratingId,
    int version,
  ) async {
    final errorMessage = writeErrorMessage(error);
    if (version == _auth.sessionVersion) {
      final code = apiErrorCode(error);
      if (code == 'AUTH401_2' || code == 'AUTH401_3' || code == 'AUTH401_4') {
        await _auth.expireSession();
      } else if (shouldRefreshAfterRatingError(error)) {
        _store.remove(ratingId, sessionVersion: version);
      }
    }
    throw RatingWriteException(errorMessage);
  }

  /// score는 항상 보내고, comment는 Dialog에 남아 있는 값을 그대로 보냅니다.
  /// 기존 후기를 지우지 않았다면 Dialog가 기존 값을 채워 두었으므로 그대로 유지됩니다.
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final version = _auth.sessionVersion;
    try {
      final updated = await _service.updateRating(
        ratingId: ratingId,
        score: score,
        comment: comment,
      );
      _store.upsert(updated, sessionVersion: version);
    } on DioException catch (error) {
      await _handleWriteError(error, ratingId, version);
    }
  }

  Future<void> deleteRating(int ratingId) async {
    final version = _auth.sessionVersion;
    try {
      await _service.deleteRating(ratingId);
      _store.remove(ratingId, sessionVersion: version);
    } on DioException catch (error) {
      await _handleWriteError(error, ratingId, version);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    _store.removeListener(load);
    super.dispose();
  }
}
