import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:movielog/core/utils/safe_notify.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/load_error_message.dart';
import 'package:movielog/view_models/load_phase.dart';

/// 영화를 page 단위로 이어서 불러오는 ViewModel. 영화 목록(Discover)과 영화 검색(Search)이
/// **각자 인스턴스를 따로** 만들어 같은 규칙으로 쓴다.
///
/// - 첫 page가 성공하면 목록을 **교체**하고, 다음 page는 **append**한다(같은 movieId는 제외).
/// - [nextPage]는 응답을 반영할 때만 올린다. 실패하면 그대로라 같은 page를 다시 요청한다.
/// - 장르·검색어·새로고침이 바뀌면([loadInitial]) 목록·page·추가 로딩 상태·오류를 모두 비우고
///   새 첫 page를 요청한다. 요청마다 `_requestGeneration`을 올려, 늦게 도착한 이전 조건의
///   응답·오류·finally는 무시한다(네트워크 요청은 취소되지 않을 수 있다).
/// - TMDB의 page는 1~500이라 `total_pages`가 더 커도 [totalPages]는 500으로 자른다.
class PagedMoviesViewModel extends ChangeNotifier with SafeNotify {
  PagedMoviesViewModel(this._service);

  /// TMDB가 허용하는 마지막 page. 501은 요청하지 않는다.
  static const maxTmdbPage = 500;

  final TmdbMovieService _service;

  LoadPhase phase = LoadPhase.idle;
  final List<TmdbMovieDto> _movies = [];

  /// 지금 화면에 쓰는 영화 목록(읽기 전용).
  List<TmdbMovieDto> get movies => UnmodifiableListView(_movies);

  /// 다음에 요청할 page. 실패하면 그대로 둔다.
  int nextPage = 1;

  /// 서버 `total_pages`와 [maxTmdbPage] 중 작은 값.
  int totalPages = 1;

  /// 다음 page를 요청 중인가. 첫 page 로딩([LoadPhase.loading])과 구분한다.
  bool isLoadingMore = false;

  /// 첫 page 조회에 실패했을 때의 안내(화면 전체 오류 상태).
  String? errorMessage;
  bool errorTimedOut = false;

  /// 다음 page 조회에 실패했을 때의 안내. 기존 목록은 지우지 않고 하단에 보여 준다.
  String? loadMoreError;

  /// 검색어를 비운 채 제출했을 때의 입력 안내(서버에는 보내지 않는다).
  String? inputHint;

  int _requestGeneration = 0;
  ({List<int>? genreIds, String query}) _condition = (
    genreIds: null,
    query: '',
  );

  /// 지금 조건의 검색어(검색 모드가 아니면 빈 문자열).
  String get query => _condition.query;

  /// 지금 조건의 장르(없으면 null = 전체).
  List<int>? get genreIds => _condition.genreIds;

  /// 첫 page 로딩 중(목록을 비우고 새로 받는 중).
  bool get isLoadingFirstPage => phase == LoadPhase.loading;

  /// 다음 page를 요청할 수 있는가(목록이 있고 마지막 page가 아니다).
  bool get hasMore => phase == LoadPhase.ready && nextPage <= totalPages;

  /// 새 조건의 첫 page를 요청한다. [query]가 있으면 검색, 없으면 Discover다.
  ///
  /// 이전 조건의 목록·nextPage·totalPages·추가 로딩 상태·오류를 모두 지우고 generation을 올린다.
  Future<void> loadInitial({List<int>? genreIds, String query = ''}) async {
    if (isDisposed) return;
    _condition = (genreIds: genreIds, query: query.trim());
    final condition = _condition;
    final generation = ++_requestGeneration;
    phase = LoadPhase.loading;
    errorMessage = null;
    errorTimedOut = false;
    loadMoreError = null;
    isLoadingMore = false;
    _movies.clear();
    nextPage = 1;
    totalPages = 1;
    notifyIfAlive();
    try {
      final page = await _fetchPage(1, condition);
      if (generation != _requestGeneration || isDisposed) return;
      _applyFirstPage(page);
    } catch (error) {
      if (generation != _requestGeneration || isDisposed) return;
      phase = LoadPhase.error;
      errorTimedOut = isTimeoutError(error);
      errorMessage = loadErrorMessage(
        error,
        fallback: condition.query.isEmpty
            ? '영화를 불러오지 못했어요. 다시 시도해 주세요.'
            : '검색 결과를 불러오지 못했어요. 다시 시도해 주세요.',
      );
    } finally {
      if (generation == _requestGeneration && !isDisposed) notifyIfAlive();
    }
  }

  /// 지금 조건 그대로 첫 page부터 다시 받는다(새로고침·오류 화면의 다시 시도).
  Future<void> reload() => loadInitial(
    genreIds: _condition.genreIds,
    query: _condition.query,
  );

  /// 검색어를 제출한다. 비어 있으면 서버에 보내지 않고 입력 안내만 남긴다.
  /// 새 검색은 이전 결과를 비우고 page 1부터 시작한다.
  Future<void> search(String rawQuery) async {
    if (isDisposed) return;
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) {
      inputHint = '검색어를 입력해 주세요.';
      notifyIfAlive();
      return;
    }
    inputHint = null;
    await loadInitial(query: trimmed);
  }

  /// 입력 안내를 지운다(사용자가 다시 입력하기 시작했을 때).
  void clearInputHint() {
    if (inputHint == null) return;
    inputHint = null;
    notifyIfAlive();
  }

  /// 다음 page를 이어서 받는다. 실패해도 [nextPage]를 올리지 않아 같은 page를 다시 요청한다.
  /// 요청 중이거나 더 받을 page가 없으면 아무것도 하지 않는다(중복 요청 방지).
  Future<void> loadNextPage() async {
    if (isDisposed || isLoadingMore || !hasMore) return;
    final generation = _requestGeneration;
    final condition = _condition;
    final pageToLoad = nextPage;
    isLoadingMore = true;
    loadMoreError = null;
    notifyIfAlive();
    try {
      final page = await _fetchPage(pageToLoad, condition);
      if (generation != _requestGeneration || isDisposed) return;
      _appendPage(page, pageToLoad);
    } catch (error) {
      if (generation != _requestGeneration || isDisposed) return;
      loadMoreError = loadErrorMessage(
        error,
        fallback: '다음 영화를 불러오지 못했어요. 다시 시도해 주세요.',
      );
    } finally {
      // 이전 조건의 요청이면 이미 loadInitial이 이 값을 초기화했으므로 건드리지 않는다.
      if (generation == _requestGeneration && !isDisposed) {
        isLoadingMore = false;
        notifyIfAlive();
      }
    }
  }

  Future<TmdbMoviePageDto> _fetchPage(
    int page,
    ({List<int>? genreIds, String query}) condition,
  ) async {
    final result = condition.query.isNotEmpty
        ? await _service.searchMovies(page: page, query: condition.query)
        : await _service.discoverMovies(
            page: page,
            genreIds: condition.genreIds,
          );
    // 요청한 page가 아닌 응답을 이어 붙이면 page가 건너뛰어지거나 겹친다.
    if (result.page != page || result.totalPages < 0) {
      throw const FormatException('TMDB page 응답이 요청과 맞지 않습니다.');
    }
    return result;
  }

  void _applyFirstPage(TmdbMoviePageDto page) {
    _movies
      ..clear()
      ..addAll(_dedupe(page.results));
    totalPages = _clampTotal(page.totalPages);
    nextPage = 2;
    phase = _movies.isEmpty ? LoadPhase.empty : LoadPhase.ready;
  }

  void _appendPage(TmdbMoviePageDto page, int pageLoaded) {
    _movies.addAll(_dedupe(page.results));
    totalPages = _clampTotal(page.totalPages);
    // 응답을 반영한 지금에서야 다음 page로 넘어간다.
    nextPage = pageLoaded + 1;
  }

  int _clampTotal(int serverTotalPages) =>
      serverTotalPages > maxTmdbPage ? maxTmdbPage : serverTotalPages;

  /// TMDB는 page가 바뀌어도 같은 영화를 다시 내려줄 수 있다. 이미 가진 movieId는 뺀다.
  List<TmdbMovieDto> _dedupe(List<TmdbMovieDto> incoming) {
    final seen = _movies.map((movie) => movie.id).toSet();
    return incoming.where((movie) => seen.add(movie.id)).toList();
  }
}
