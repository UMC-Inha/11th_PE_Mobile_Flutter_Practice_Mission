import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_request.dart';
import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

/// "내가 등록한 평점" 화면의 조회·수정·삭제 상태를 관리합니다.
/// memberId는 회원가입 결과를 보관한 LearningMemberSession에서 받습니다. 인증은 아닙니다.
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, this._movieService, this.memberId);
  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final int memberId;

  /// movieId → TMDB 영화입니다. 같은 movieId는 한 번만 묻고, TMDB에 없는 영화(null)도 저장합니다.
  final Map<int, TmdbMovieDto?> _moviesById = {};
  int _requestVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;

  /// Error 상태에서는 실패 문구, Success 상태에서는 영화 정보 누락 안내입니다.
  String? message;

  /// 수정·삭제는 성공했지만 이어진 목록 재조회(GET)만 실패했을 때의 안내입니다.
  String? refreshWarning;

  Future<void> load() async {
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    notifyListeners();

    bool isStale() => _disposed || version != _requestVersion;

    try {
      final rawRatings = await _service.fetchMyRatings(memberId);
      if (isStale()) return;

      final entries = <RatingWithMovie>[];
      var missingMovies = 0;
      // 영화 조회 실패가 평점 목록을 지우지 않습니다.
      for (final rating in rawRatings) {
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
      refreshWarning = null;
      status = entries.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
      if (missingMovies > 0) {
        message = '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.';
      }
    } on DioException catch (error) {
      if (isStale()) return;
      status = MyRatingsLoadStatus.error;
      message = writeMyRatingsErrorMessage(error);
    }
    if (!isStale()) notifyListeners();
  }

  /// 쓰기 성공 뒤 목록을 다시 읽습니다. GET 실패는 저장 실패로 다시 던지지 않습니다.
  Future<void> _refreshAfterWrite() async {
    await load();
    if (_disposed) return;
    if (status == MyRatingsLoadStatus.error) {
      refreshWarning = '저장은 완료됐지만 목록을 불러오지 못했습니다. 조회만 다시 시도해 주세요.';
      notifyListeners();
    }
  }

  /// 쓰기 실패를 Dialog가 보여줄 예외로 바꿉니다. 403·404면 목록을 서버 상태와 맞춥니다.
  Future<Never> _handleWriteError(DioException error) async {
    final errorMessage = writeErrorMessage(error);
    if (shouldRefreshAfterRatingError(error) && !_disposed) await load();
    throw RatingWriteException(errorMessage);
  }

  /// score는 항상 보내고, comment는 Dialog에 남아 있는 값을 그대로 보냅니다.
  /// 기존 후기를 지우지 않았다면 Dialog가 기존 값을 채워 두었으므로 그대로 유지됩니다.
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    try {
      await _service.updateRating(
        memberId: memberId,
        ratingId: ratingId,
        request: UpdateRatingRequest(score: score, comment: comment),
      );
    } on DioException catch (error) {
      await _handleWriteError(error);
    }
    if (_disposed) return;
    await _refreshAfterWrite();
  }

  Future<void> deleteRating(int ratingId) async {
    try {
      await _service.deleteRating(memberId: memberId, ratingId: ratingId);
    } on DioException catch (error) {
      await _handleWriteError(error);
    }
    if (_disposed) return;
    await _refreshAfterWrite();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
