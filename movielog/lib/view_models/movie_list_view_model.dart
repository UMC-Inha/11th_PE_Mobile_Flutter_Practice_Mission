import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';

enum MovieListLoadStatus { idle, loading, success, empty, error }

/// 영화 목록 화면의 장르 목록, 선택 장르, Discover 최대 30개 상태를 관리합니다.
class MovieListViewModel extends ChangeNotifier {
  MovieListViewModel(this._service);
  final TmdbMovieService _service;

  List<TmdbMovieDto> movies = const [];
  List<TmdbGenreDto> genres = const [];
  int? selectedGenreId;
  MovieListLoadStatus status = MovieListLoadStatus.idle;
  String? message;

  /// 늦게 도착한 이전 요청의 결과를 무시하기 위한 요청 번호입니다.
  int _requestVersion = 0;
  bool _disposed = false;

  /// TMDB `id` 기준으로 중복을 제거하며 결과가 30개가 되거나 페이지가 끝날 때까지 요청합니다.
  Future<List<TmdbMovieDto>> fetchUpToThirtyMovies({int? genreId}) async {
    final byId = <int, TmdbMovieDto>{};
    var pageNumber = 1;
    var hasNextPage = true;

    while (byId.length < 30 && hasNextPage) {
      final page = await _service.discoverMovies(
        page: pageNumber,
        genreId: genreId,
      );

      for (final movie in page.results) {
        byId[movie.id] = movie;
        if (byId.length == 30) break;
      }

      hasNextPage = pageNumber < page.totalPages && page.results.isNotEmpty;
      pageNumber++;
    }

    return byId.values.take(30).toList();
  }

  Future<void> loadInitial() async {
    final version = ++_requestVersion;
    status = MovieListLoadStatus.loading;
    notifyListeners();

    try {
      genres = await _service.fetchGenres();
      // 재시도할 때도 마지막으로 선택한 장르 조건을 유지합니다.
      final discovered = await fetchUpToThirtyMovies(genreId: selectedGenreId);

      if (_disposed || version != _requestVersion) return;
      movies = discovered;
      status = movies.isEmpty
          ? MovieListLoadStatus.empty
          : MovieListLoadStatus.success;
    } on DioException {
      if (_disposed || version != _requestVersion) return;
      status = MovieListLoadStatus.error;
      message = '영화를 불러오지 못했어요. 다시 시도해 주세요.';
    } catch (error, stackTrace) {
      // 응답 형식이 달라 DTO 변환에 실패한 경우 등도 Loading에 멈추지 않고 Error로 보여줍니다.
      debugPrint('영화 목록 처리 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (_disposed || version != _requestVersion) return;
      status = MovieListLoadStatus.error;
      message = '영화를 불러오지 못했어요. 다시 시도해 주세요.';
    }

    if (!_disposed && version == _requestVersion) notifyListeners();
  }

  /// Discover 요청 중에는 장르를 바꿀 수 없습니다.
  bool get canChangeGenre => status != MovieListLoadStatus.loading;

  /// 장르를 바꾸면 `with_genres` 조건으로 page 1부터 다시 조회합니다. null은 전체입니다.
  Future<void> selectGenre(int? genreId) async {
    if (!canChangeGenre) return;

    selectedGenreId = genreId;
    final version = ++_requestVersion;
    status = MovieListLoadStatus.loading;
    notifyListeners();

    try {
      final result = await fetchUpToThirtyMovies(genreId: genreId);
      if (_disposed || version != _requestVersion) return;
      movies = result;
      status = result.isEmpty
          ? MovieListLoadStatus.empty
          : MovieListLoadStatus.success;
    } on DioException {
      if (_disposed || version != _requestVersion) return;
      status = MovieListLoadStatus.error;
      message = '해당 장르 영화를 불러오지 못했어요.';
    } catch (error, stackTrace) {
      debugPrint('장르 영화 처리 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (_disposed || version != _requestVersion) return;
      status = MovieListLoadStatus.error;
      message = '해당 장르 영화를 불러오지 못했어요.';
    }

    if (!_disposed && version == _requestVersion) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
