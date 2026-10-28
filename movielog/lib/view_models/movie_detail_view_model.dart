import 'package:flutter/foundation.dart';
import 'package:movielog/data/models/movielog_dtos.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/load_error_message.dart';

enum MovieDetailLoadStatus { loading, success, error }

/// 영화 상세 ViewModel. 목록에서 넘겨받은 DTO가 있으면 바로 쓰고,
/// 주소로 바로 열었으면 Route의 TMDB `movieId`로 Movie Details를 조회한다.
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(this._service, {required this.movieId, this.movie})
    : status = movie == null
          ? MovieDetailLoadStatus.loading
          : MovieDetailLoadStatus.success;

  final TmdbMovieService _service;
  final int movieId;
  TmdbMovieDto? movie;
  MovieDetailLoadStatus status;
  String? message;

  bool isFavorite = false;

  /// 이 화면에서 남긴 평점(1~5). 6주차에 자체 백엔드 POST로 보낸다.
  CreateRatingRequest? myRating;

  bool _disposed = false;

  Future<void> loadIfNeeded() async {
    if (movie != null) return;
    status = MovieDetailLoadStatus.loading;
    notifyListeners();
    try {
      final result = await _service.fetchMovie(movieId);
      if (_disposed) return;
      movie = result;
      status = MovieDetailLoadStatus.success;
    } catch (error) {
      if (_disposed) return;
      status = MovieDetailLoadStatus.error;
      message = loadErrorMessage(error, fallback: '영화 정보를 불러오지 못했어요.');
    }
    notifyListeners();
  }

  void toggleFavorite() {
    isFavorite = !isFavorite;
    notifyListeners();
  }

  /// 평점 Dialog 결과를 TMDB id가 담긴 요청 Body로 만든다.
  CreateRatingRequest rate(int score) {
    final request = CreateRatingRequest(movieId: movieId, score: score);
    myRating = request;
    notifyListeners();
    return request;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
