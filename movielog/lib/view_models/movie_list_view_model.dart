import 'package:flutter/foundation.dart';
import 'package:movielog/core/storage/genre_preference.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/load_error_message.dart';

enum MovieListLoadStatus { idle, loading, success, empty, error }

/// 영화 목록 화면 ViewModel.
///
/// - Genre API로 장르 Chip을 만들고, Discover를 page 1부터 불러 최대 30개를 만든다.
/// - 장르를 바꾸면 로컬 where가 아니라 `with_genres`로 page 1부터 다시 요청한다.
/// - 늦게 도착한 이전 요청 응답은 request version으로 버린다.
class MovieListViewModel extends ChangeNotifier {
  MovieListViewModel(this._service, {this._preferences, this._initialGenreIds});

  static const maxMovies = 30;

  final TmdbMovieService _service;
  final MoviePreferences? _preferences;

  /// 주소(`/movies?genres=28`)로 장르를 지정해 열었으면 저장값보다 우선한다.
  final List<int>? _initialGenreIds;

  List<TmdbMovieDto> movies = const [];
  List<TmdbGenreDto> genres = const [];

  /// 비어 있으면 "전체". 여러 개면 OR(`|`)로 요청한다.
  List<int> selectedGenreIds = const [];
  MovieSort sort = MovieSort.original;
  MovieListLoadStatus status = MovieListLoadStatus.idle;
  String? message;
  bool timedOut = false;

  /// Pull to Refresh·재시도처럼 기존 목록을 보여 둔 채 다시 불러오는 중.
  bool isRefreshing = false;

  /// 최근 성공 목록을 유지한 채 요청이 실패한 횟수. 바뀔 때마다 View가 재시도 Dialog를 띄운다.
  int retryNoticeCount = 0;

  /// Discover 요청 횟수(page 단위). 테스트·트러블슈팅 기록용.
  int discoverRequestCount = 0;

  List<int> _lastSuccessGenreIds = const [];
  int _requestVersion = 0;
  bool _disposed = false;
  Future<void> _saveQueue = Future<void>.value();

  bool get isBusy => status == MovieListLoadStatus.loading || isRefreshing;

  /// Discover 요청 중에는 장르를 바꾸지 못한다.
  bool get canChangeGenre => !isBusy;

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

  /// 정렬은 이미 받은 30개 안에서만 바꾸는 화면 정책이다(재요청하지 않는다).
  List<TmdbMovieDto> get visibleMovies {
    final sorted = List<TmdbMovieDto>.of(movies);
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

  /// 결과가 30개가 되거나 더 이상 페이지가 없을 때까지 page를 늘려 요청한다.
  /// 한 페이지 개수(20)를 코드에 박지 않고, TMDB `id`를 Map key로 써서 중복을 없앤다.
  Future<List<TmdbMovieDto>> fetchUpToThirtyMovies({
    List<int>? genreIds,
  }) async {
    final byId = <int, TmdbMovieDto>{};
    var pageNumber = 1;
    var hasNextPage = true;

    while (byId.length < maxMovies && hasNextPage) {
      discoverRequestCount++;
      final page = await _service.discoverMovies(
        page: pageNumber,
        genreIds: genreIds,
      );

      for (final movie in page.results) {
        byId[movie.id] = movie;
        if (byId.length == maxMovies) break;
      }

      hasNextPage = pageNumber < page.totalPages && page.results.isNotEmpty;
      pageNumber++;
    }

    return byId.values.take(maxMovies).toList();
  }

  Future<void> loadInitial() async {
    final version = ++_requestVersion;
    status = MovieListLoadStatus.loading;
    message = null;
    notifyListeners();

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
      _fail(error, fallback: '장르를 불러오지 못했어요. 다시 시도해 주세요.');
      notifyListeners();
      return;
    }
    await _loadMovies(version: version);
  }

  /// Chip 하나(단일 선택). null 또는 "전체"는 `with_genres` 없이 요청한다.
  Future<void> selectGenre(int? genreId) =>
      selectGenres(genreId == null ? null : [genreId]);

  /// BottomSheet 다중 선택. 선택이 바뀌면 목록을 초기화하고 page 1부터 다시 불러온다.
  Future<void> selectGenres(List<int>? genreIds) async {
    if (!canChangeGenre) return;
    final next = List<int>.unmodifiable(genreIds ?? const <int>[]);
    if (listEquals(next, selectedGenreIds) &&
        status != MovieListLoadStatus.error) {
      return;
    }
    selectedGenreIds = next;
    _persist();
    await _loadMovies(version: ++_requestVersion);
  }

  /// Pull to Refresh. 현재 장르를 유지한 채 page 1부터 다시 부르고,
  /// 끝날 때까지 기존 목록을 화면에 남겨 둔다. Loading 중에는 동작하지 않는다.
  Future<void> refresh() async {
    if (isBusy) return;
    if (genres.isEmpty) return loadInitial();
    await _loadMovies(version: ++_requestVersion, keepVisible: true);
  }

  /// 오류 화면·재시도 Dialog의 "다시 시도". 마지막으로 고른 장르 ID 목록으로 30개 로딩 전체를 다시 한다.
  Future<void> retry() async {
    if (genres.isEmpty) return loadInitial();
    await _loadMovies(
      version: ++_requestVersion,
      keepVisible: movies.isNotEmpty,
    );
  }

  /// 재시도 Dialog에서 취소: 화면에 남아 있는 최근 성공 목록과 장르 선택을 맞춘다.
  void cancelRetry() {
    if (listEquals(selectedGenreIds, _lastSuccessGenreIds)) return;
    selectedGenreIds = _lastSuccessGenreIds;
    _persist();
    notifyListeners();
  }

  void setSort(MovieSort value) {
    if (sort == value) return;
    sort = value;
    _persist();
    notifyListeners();
  }

  Future<void> _loadMovies({
    required int version,
    bool keepVisible = false,
  }) async {
    if (keepVisible) {
      isRefreshing = true;
    } else {
      status = MovieListLoadStatus.loading;
    }
    message = null;
    notifyListeners();

    final requestedGenreIds = selectedGenreIds;
    try {
      final result = await fetchUpToThirtyMovies(genreIds: requestedGenreIds);
      if (_isStale(version)) return;
      movies = result;
      _lastSuccessGenreIds = requestedGenreIds;
      status = result.isEmpty
          ? MovieListLoadStatus.empty
          : MovieListLoadStatus.success;
    } catch (error) {
      if (_isStale(version)) return;
      _fail(error, fallback: '영화를 불러오지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (!_isStale(version)) isRefreshing = false;
    }
    if (!_isStale(version)) notifyListeners();
  }

  void _fail(Object error, {required String fallback}) {
    message = loadErrorMessage(error, fallback: fallback);
    timedOut = isTimeoutError(error);
    if (movies.isNotEmpty) {
      // 최근에 성공한 목록이 있으면 바로 비우지 않고 Dialog로 재시도를 묻는다.
      status = MovieListLoadStatus.success;
      retryNoticeCount++;
    } else {
      status = MovieListLoadStatus.error;
    }
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

  bool _isStale(int version) => _disposed || version != _requestVersion;

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
