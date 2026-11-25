import 'package:flutter/foundation.dart';

import '../core/utils/safe_notify.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/models/tmdb_movie_page.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_phase.dart';

/// 영화 목록(Discover)과 검색(Search)이 함께 쓰는 page 단위 목록 상태입니다.
/// 화면마다 별도 인스턴스를 만들어 사용합니다.
class PagedMoviesViewModel extends ChangeNotifier with SafeNotify {
  PagedMoviesViewModel({required this.tmdbApi});

  final TmdbMovieService tmdbApi;

  static const maxTmdbPage = 500;

  LoadPhase phase = LoadPhase.idle;
  final List<TmdbMovieDto> movies = [];

  /// 다음에 요청할 page이며 실패하면 그대로 둡니다.
  int nextPage = 1;

  /// 서버 total_pages와 TMDB 최대 500 중 작은 값입니다.
  int totalPages = 1;
  bool isLoadingMore = false;
  bool get hasMore => nextPage <= totalPages;
  String? errorMessage;

  /// 기존 목록을 지우지 않고 하단에 보여줄 추가 조회 오류입니다.
  String? loadMoreError;

  /// 조건(장르·검색어)이 바뀔 때마다 올려 이전 조건의 늦은 응답을 버립니다.
  int _requestGeneration = 0;
  ({int? genreId, String query}) _condition = (genreId: null, query: '');

  int? get genreId => _condition.genreId;
  String get query => _condition.query;

  Future<void> loadInitial({int? genreId, String query = ''}) async {
    if (isDisposed) return;
    _condition = (genreId: genreId, query: query.trim());
    final generation = ++_requestGeneration;
    phase = LoadPhase.loading;
    errorMessage = null;
    loadMoreError = null;
    isLoadingMore = false;
    movies.clear();
    nextPage = 1;
    totalPages = 1;
    notifyIfAlive();
    try {
      final page = await _fetchPage(1, _condition);
      if (generation != _requestGeneration || isDisposed) return;
      _applyFirstPage(page);
    } catch (_) {
      if (generation != _requestGeneration || isDisposed) return;
      phase = LoadPhase.error;
      errorMessage = _condition.query.isEmpty
          ? '영화 목록을 불러오지 못했습니다.'
          : '검색 결과를 불러오지 못했습니다.';
    } finally {
      if (generation == _requestGeneration && !isDisposed) notifyIfAlive();
    }
  }

  /// 현재 조건을 유지한 채 첫 page부터 다시 불러옵니다.
  Future<void> reload() => loadInitial(genreId: genreId, query: query);

  // 실패해도 nextPage를 올리지 않아 같은 page를 다시 요청할 수 있습니다.
  Future<void> loadNextPage() async {
    if (isDisposed || isLoadingMore || !hasMore || phase != LoadPhase.ready) {
      return;
    }
    final generation = _requestGeneration;
    final pageToLoad = nextPage;
    isLoadingMore = true;
    loadMoreError = null;
    notifyIfAlive();
    try {
      final page = await _fetchPage(pageToLoad, _condition);
      if (generation != _requestGeneration || isDisposed) return;
      _appendPage(page);
    } catch (_) {
      if (generation != _requestGeneration || isDisposed) return;
      loadMoreError = '다음 페이지를 불러오지 못했습니다. 같은 페이지를 다시 요청합니다.';
    } finally {
      if (generation == _requestGeneration && !isDisposed) {
        isLoadingMore = false;
        notifyIfAlive();
      }
    }
  }

  Future<TmdbMoviePageDto> _fetchPage(
    int page,
    ({int? genreId, String query}) condition,
  ) async {
    final result = condition.query.isNotEmpty
        ? await tmdbApi.searchMovies(page: page, query: condition.query)
        : await tmdbApi.discoverMovies(page: page, genreId: condition.genreId);
    if (result.page != page || result.page < 1 || result.totalPages < 0) {
      throw const FormatException('TMDB page metadata is inconsistent.');
    }
    return result;
  }

  int _clampTotal(int total) => total > maxTmdbPage ? maxTmdbPage : total;

  void _applyFirstPage(TmdbMoviePageDto page) {
    movies
      ..clear()
      ..addAll(_dedupe(page.results));
    totalPages = _clampTotal(page.totalPages);
    nextPage = page.page + 1;
    phase = movies.isEmpty ? LoadPhase.empty : LoadPhase.ready;
  }

  void _appendPage(TmdbMoviePageDto page) {
    movies.addAll(_dedupe(page.results));
    totalPages = _clampTotal(page.totalPages);
    nextPage = page.page + 1;
  }

  /// TMDB는 page가 바뀌어도 같은 영화를 다시 줄 수 있어 이미 가진 id는 제외합니다.
  List<TmdbMovieDto> _dedupe(List<TmdbMovieDto> incoming) {
    final seen = movies.map((movie) => movie.id).toSet();
    return incoming
        .where((movie) => seen.add(movie.id))
        .toList(growable: false);
  }
}
