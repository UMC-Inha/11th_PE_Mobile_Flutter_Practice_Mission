import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';

/// 인증된 '내 계정'이 아닌 학습용 데이터입니다. 실제 회원 식별은 JWT 주차에서 바뀝니다.
const int sampleMemberId = 3; // TODO: Empty 화면 캡처용 임시 값. 캡처 후 1로 되돌립니다.

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

/// "내가 등록한 평점" 화면의 상태를 관리합니다.
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
            _moviesById[rating.movieId] =
                await _movieService.findMovieById(rating.movieId);
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
    } on DioException catch (error) {
      if (isStale()) return;
      status = MyRatingsLoadStatus.error;
      message = writeMyRatingsErrorMessage(error);
    }
    if (!isStale()) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
