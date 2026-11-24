import 'package:flutter/foundation.dart';
import 'package:movielog/core/storage/genre_preference.dart';
import 'package:movielog/core/utils/safe_notify.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/load_error_message.dart';
import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';

enum MovieListLoadStatus { idle, loading, success, empty, error }

/// 영화 목록 화면 ViewModel.
///
/// 장르 Chip·BottomSheet 선택, 저장된 장르·정렬 복원, 카드의 장르 이름처럼 **목록 화면만의 정책**을
/// 맡고, 영화를 page 단위로 받아 오는 일은 [paged]([PagedMoviesViewModel])에 맡긴다.
/// (5주차의 "Discover를 여러 번 불러 30개 수집" 방식은 이 화면에서 "더 보기"로 대체했다.)
///
/// - 첫 page만 불러오고, 다음 page는 [PagedMoviesViewModel.loadNextPage]를 부를 때 받는다.
/// - 장르를 바꾸면 `with_genres`로 page 1부터 다시 요청한다. 이전 장르의 늦은 응답은
///   [paged]의 generation이 버리므로 요청 중에도 장르를 바꿀 수 있다.
/// - 정렬은 지금까지 불러온 영화 안에서만 바꾸는 화면 정책이다(재요청하지 않는다).
class MovieListViewModel extends ChangeNotifier with SafeNotify {
  MovieListViewModel(
    this._service, {
    this._preferences,
    this._initialGenreIds,
    PagedMoviesViewModel? paged,
  }) : paged = paged ?? PagedMoviesViewModel(_service) {
    this.paged.addListener(notifyIfAlive);
  }

  final TmdbMovieService _service;
  final MoviePreferences? _preferences;

  /// 주소(`/movies?genres=28`)로 장르를 지정해 열었으면 저장값보다 우선한다.
  final List<int>? _initialGenreIds;

  /// page 단위 목록 상태(movies, nextPage, isLoadingMore, loadMoreError…). 이 화면 전용 인스턴스다.
  final PagedMoviesViewModel paged;

  List<TmdbGenreDto> genres = const [];

  /// 비어 있으면 "전체". 여러 개면 OR(`|`)로 요청한다.
  List<int> selectedGenreIds = const [];
  MovieSort sort = MovieSort.original;

  // 장르 목록(Genre API)을 받는 동안·실패했을 때의 상태. 영화 page 상태는 [paged]가 갖는다.
  bool _loadingGenres = false;
  String? _genreFailure;
  bool _genreTimedOut = false;
  int _initVersion = 0;
  Future<void> _saveQueue = Future<void>.value();

  /// 화면이 그릴 상태 하나. 장르 목록 조회와 영화 page 조회를 합쳐 보여 준다.
  MovieListLoadStatus get status {
    if (_genreFailure != null) return MovieListLoadStatus.error;
    if (_loadingGenres) return MovieListLoadStatus.loading;
    return switch (paged.phase) {
      LoadPhase.idle => MovieListLoadStatus.idle,
      LoadPhase.loading => MovieListLoadStatus.loading,
      LoadPhase.ready => MovieListLoadStatus.success,
      LoadPhase.empty => MovieListLoadStatus.empty,
      LoadPhase.error => MovieListLoadStatus.error,
    };
  }

  String? get message => _genreFailure ?? paged.errorMessage;
  bool get timedOut =>
      _genreFailure != null ? _genreTimedOut : paged.errorTimedOut;

  /// 지금까지 불러온 영화(받은 순서).
  List<TmdbMovieDto> get movies => paged.movies;

  /// 장르 목록을 받는 중이 아니면 언제든 장르를 바꿀 수 있다. 요청 중에 바꿔도
  /// 이전 장르의 늦은 응답은 generation이 버린다.
  bool get canChangeGenre => !_loadingGenres && _genreFailure == null;

  String? genreName(int id) {
    for (final genre in genres) {
      if (genre.id == id) return genre.name;
    }
    return null;
  }

  /// 카드에 보여줄 장르 이름. 장르로 걸러 봤다면 고른 장르를 먼저 보여준다.
  String? primaryGenreName(TmdbMovieDto movie) {
    for (final id in selectedGenreIds) {
      if (movie.genreIds.contains(id)) return genreName(id);
    }
    for (final id in movie.genreIds) {
      final name = genreName(id);
      if (name != null) return name;
    }
    return null;
  }

  String get selectionLabel {
    if (selectedGenreIds.isEmpty) return '전체';
    return selectedGenreIds.map((id) => genreName(id) ?? '#$id').join(', ');
  }

  /// 정렬은 지금까지 받은 영화 안에서만 바꾸는 화면 정책이다(재요청하지 않는다).
  List<TmdbMovieDto> get visibleMovies {
    final sorted = List<TmdbMovieDto>.of(paged.movies);
    switch (sort) {
      case MovieSort.original:
        break;
      case MovieSort.title:
        sorted.sort((a, b) => a.title.compareTo(b.title));
      case MovieSort.rating:
        sorted.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
    }
    return sorted;
  }

  /// 장르 목록과 저장된 설정을 불러온 뒤 첫 page를 요청한다.
  Future<void> loadInitial() async {
    final version = ++_initVersion;
    _loadingGenres = true;
    _genreFailure = null;
    _genreTimedOut = false;
    notifyIfAlive();

    try {
      final results = await Future.wait<Object?>([
        _service.fetchGenres(),
        _preferences?.read() ?? Future<MovieListSettings?>.value(),
      ]);
      if (_isStale(version)) return;
      genres = results[0] as List<TmdbGenreDto>;
      final settings = results[1] as MovieListSettings?;
      if (settings != null) sort = settings.sort;
      final wanted = _initialGenreIds ?? settings?.genreIds ?? const [];
      // 저장돼 있던 ID가 TMDB 장르 목록에 없으면 버린다.
      final known = genres.map((genre) => genre.id).toSet();
      selectedGenreIds = wanted.where(known.contains).toList();
    } catch (error) {
      if (_isStale(version)) return;
      _loadingGenres = false;
      _genreTimedOut = isTimeoutError(error);
      _genreFailure = loadErrorMessage(
        error,
        fallback: '장르를 불러오지 못했어요. 다시 시도해 주세요.',
      );
      notifyIfAlive();
      return;
    }
    _loadingGenres = false;
    await paged.loadInitial(genreIds: selectedGenreIds);
  }

  /// Chip 하나(단일 선택). null 또는 "전체"는 `with_genres` 없이 요청한다.
  Future<void> selectGenre(int? genreId) =>
      selectGenres(genreId == null ? null : [genreId]);

  /// BottomSheet 다중 선택. 선택이 바뀌면 목록을 초기화하고 page 1부터 다시 불러온다.
  Future<void> selectGenres(List<int>? genreIds) async {
    if (isDisposed || !canChangeGenre) return;
    final next = List<int>.unmodifiable(genreIds ?? const <int>[]);
    if (listEquals(next, selectedGenreIds) && paged.phase != LoadPhase.error) {
      return;
    }
    selectedGenreIds = next;
    _persist();
    notifyIfAlive();
    await paged.loadInitial(genreIds: next);
  }

  /// Pull to Refresh·오류 화면의 "다시 시도". 지금 장르를 유지한 채 page 1부터 다시 받는다.
  /// 장르 목록부터 실패했다면 처음부터 다시 한다.
  Future<void> refresh() {
    if (genres.isEmpty || _genreFailure != null) return loadInitial();
    return paged.reload();
  }

  void setSort(MovieSort value) {
    if (sort == value) return;
    sort = value;
    _persist();
    notifyIfAlive();
  }

  void _persist() {
    final preferences = _preferences;
    if (preferences == null) return;
    final settings = MovieListSettings(genreIds: selectedGenreIds, sort: sort);
    // 빠르게 여러 번 바꿔도 이전 저장이 최신 선택을 덮어쓰지 않게 차례로 저장한다.
    _saveQueue = _saveQueue
        .then((_) => preferences.save(settings))
        .catchError((Object _) {});
  }

  /// 테스트에서 저장이 끝날 때까지 기다린다.
  @visibleForTesting
  Future<void> get pendingSave => _saveQueue;

  bool _isStale(int version) => isDisposed || version != _initVersion;

  @override
  void dispose() {
    _initVersion++;
    paged.removeListener(notifyIfAlive);
    paged.dispose();
    super.dispose();
  }
}
