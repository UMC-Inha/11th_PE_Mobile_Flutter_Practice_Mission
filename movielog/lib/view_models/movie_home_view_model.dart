import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';

enum MovieHomeLoadStatus { idle, loading, success, empty, error }

/// 홈 화면의 인기 영화(Popular 앞 5개) 상태를 관리합니다.
class MovieHomeViewModel extends ChangeNotifier {
  MovieHomeViewModel(this._service);
  final TmdbMovieService _service;

  List<TmdbMovieDto> popularMovies = const [];
  MovieHomeLoadStatus status = MovieHomeLoadStatus.idle;
  String? message;

  /// 응답을 기다리는 동안 화면을 떠나 dispose된 뒤에는 상태를 바꾸지 않기 위한 플래그입니다.
  bool _disposed = false;

  Future<void> loadPopular() async {
    status = MovieHomeLoadStatus.loading;
    notifyListeners();

    try {
      final page = await _service.fetchPopular();
      if (_disposed) return;
      // 결과가 5개보다 적어도 take(5)는 있는 만큼만 반환합니다.
      popularMovies = page.results.take(5).toList();
      status = popularMovies.isEmpty
          ? MovieHomeLoadStatus.empty
          : MovieHomeLoadStatus.success;
    } on DioException {
      if (_disposed) return;
      status = MovieHomeLoadStatus.error;
      message = '인기 영화를 불러오지 못했어요.';
    } catch (error, stackTrace) {
      // 응답 형식이 달라 DTO 변환에 실패한 경우 등도 Loading에 멈추지 않고 Error로 보여줍니다.
      debugPrint('인기 영화 처리 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (_disposed) return;
      status = MovieHomeLoadStatus.error;
      message = '인기 영화를 불러오지 못했어요.';
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
