import 'package:flutter/foundation.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/load_error_message.dart';

enum MovieHomeLoadStatus { idle, loading, success, empty, error }

/// 홈 화면 ViewModel. Popular 첫 페이지에서 앞 5개만 홈 인기 영역에 쓴다.
class MovieHomeViewModel extends ChangeNotifier {
  MovieHomeViewModel(this._service);

  static const popularCount = 5;

  final TmdbMovieService _service;

  List<TmdbMovieDto> popularMovies = const [];
  MovieHomeLoadStatus status = MovieHomeLoadStatus.idle;
  String? message;

  int _requestVersion = 0;
  bool _disposed = false;

  Future<void> loadPopular() async {
    final version = ++_requestVersion;
    status = MovieHomeLoadStatus.loading;
    message = null;
    notifyListeners();

    try {
      final page = await _service.fetchPopular();
      if (_isStale(version)) return;
      // [0]~[4]를 직접 꺼내지 않는다. 5개보다 적으면 있는 만큼만 돌려준다.
      popularMovies = page.results.take(popularCount).toList();
      status = popularMovies.isEmpty
          ? MovieHomeLoadStatus.empty
          : MovieHomeLoadStatus.success;
    } catch (error) {
      if (_isStale(version)) return;
      status = MovieHomeLoadStatus.error;
      message = loadErrorMessage(error, fallback: '인기 영화를 불러오지 못했어요.');
    }
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
