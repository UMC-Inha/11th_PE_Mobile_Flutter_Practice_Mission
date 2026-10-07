import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/core/data/mock_movies.dart';
import 'package:movielog/core/services/fake_movie_service.dart';
import 'package:movielog/core/storage/genre_preference.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/features/movies/presentation/widgets/genre_filter_sheet.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_grid.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_list_states.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_list_tile.dart';

const filterButtonKey = Key('filterButton');
const viewModeButtonKey = Key('viewModeButton');

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({
    super.key,
    required this.selectedGenres,
    this.restoreSavedGenre = true,
    this.service = const FakeMovieService(),
    this.preferences,
    this.initialMode = MovieLoadMode.success,
  });
  final Set<String> selectedGenres;
  final bool restoreSavedGenre;
  final MovieService service;
  final MoviePreferences? preferences;
  final MovieLoadMode initialMode;
  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  late Future<List<Movie>> _moviesFuture;
  late final MoviePreferences _preferences;
  late Set<String> _genres;
  MovieSort _sort = MovieSort.original;
  bool _isGrid = true;
  bool _initialized = false;
  bool _selectionChanged = false;
  bool _sortChanged = false;
  int _selectionVersion = 0;
  Future<void> _saveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _genres = Set.of(widget.selectedGenres);
    _preferences = widget.preferences ?? GenrePreference();
    _moviesFuture = _loadInitialData(widget.initialMode);
  }

  @override
  void didUpdateWidget(covariant MovieListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!setEquals(oldWidget.selectedGenres, widget.selectedGenres) &&
        !setEquals(_genres, widget.selectedGenres)) {
      _genres = Set.of(widget.selectedGenres);
      _selectionChanged = true;
      _persist();
    }
  }

  Future<List<Movie>> _fetch(MovieLoadMode mode) async {
    try {
      return await widget.service
          .fetchMovies(mode: mode)
          .timeout(const Duration(seconds: 2));
    } on MovieLoadException catch (error, stack) {
      debugPrint('영화 조회 실패: $error');
      debugPrintStack(stackTrace: stack);
      rethrow;
    } finally {
      debugPrint('영화 조회 시도 종료');
    }
  }

  Future<List<Movie>> _loadInitialData(MovieLoadMode mode) async {
    final results = await Future.wait<Object>([
      _fetch(mode),
      _preferences.read(),
    ]);
    final settings = results[1] as MovieListSettings;
    if (mounted) {
      setState(() {
        if (widget.restoreSavedGenre && !_selectionChanged) {
          _genres = Set.of(settings.genres);
        }
        if (!_sortChanged) _sort = settings.sort;
        _initialized = true;
      });
    }
    return results[0] as List<Movie>;
  }

  Future<void> _reload([MovieLoadMode mode = MovieLoadMode.success]) async {
    final future = _initialized ? _fetch(mode) : _loadInitialData(mode);
    setState(() {
      _moviesFuture = future;
    });
    // FutureBuilder가 오류 UI를 그린다. RefreshIndicator에는 오류를 전달하지 않는다.
    try {
      await future;
    } catch (_) {
      /* 화면에서 다시 시도할 수 있다. */
    }
  }

  Future<void> _persist() {
    final settings = MovieListSettings(genres: Set.of(_genres), sort: _sort);
    // 빠르게 여러 Chip을 눌러도 이전 저장이 최신 선택을 덮어쓰지 않게 직렬화한다.
    _saveQueue = _saveQueue.then((_) => _preferences.save(settings)).catchError(
      (Object error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('설정을 저장하지 못했어요. 다시 선택해 주세요.')),
        );
      },
    );
    return _saveQueue;
  }

  Future<void> _selectGenres(Set<String> genres) async {
    setState(() {
      _genres = Set.of(genres);
      _selectionChanged = true;
    });
    final version = ++_selectionVersion;
    await _persist();
    if (!mounted || version != _selectionVersion) return;
    // 장르 변경은 이미 받은 목록만 필터링하고 새 Future를 만들지 않는다.
    context.go(moviesLocation(genres));
  }

  Future<void> _openFilter() async {
    final result = await showGenreFilterSheet(
      context,
      initialSelection: _genres,
    );
    if (result == null || !mounted) return;
    _selectGenres(result);
  }

  List<Movie> _visibleMovies(List<Movie> movies) {
    final filtered = movies
        .where((m) => _genres.isEmpty || _genres.contains(m.genre))
        .toList();
    switch (_sort) {
      case MovieSort.original:
        break;
      case MovieSort.title:
        filtered.sort((a, b) => a.title.compareTo(b.title));
      case MovieSort.rating:
        filtered.sort((a, b) => b.averageRating.compareTo(a.averageRating));
    }
    return filtered;
  }

  void _openDetail(Movie movie) =>
      context.push(AppRoutes.movieDetail(movie.id));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('영화', style: TextStyle(fontWeight: FontWeight.w800)),
      actions: [
        IconButton(
          key: viewModeButtonKey,
          tooltip: _isGrid ? '리스트로 보기' : '격자로 보기',
          onPressed: () => setState(() => _isGrid = !_isGrid),
          icon: Icon(_isGrid ? Icons.view_list : Icons.grid_view),
        ),
        IconButton(
          key: filterButtonKey,
          tooltip: '장르 필터',
          onPressed: _openFilter,
          icon: Badge(
            isLabelVisible: _genres.isNotEmpty,
            label: Text('${_genres.length}'),
            child: const Icon(Icons.filter_list),
          ),
        ),
        if (kDebugMode)
          PopupMenuButton<MovieLoadMode>(
            key: const Key('loadModeMenu'),
            tooltip: '목록 상태 확인',
            onSelected: (mode) => _reload(mode),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: MovieLoadMode.success,
                child: Text('성공 화면 확인'),
              ),
              PopupMenuItem(value: MovieLoadMode.empty, child: Text('빈 목록 확인')),
              PopupMenuItem(
                value: MovieLoadMode.failure,
                child: Text('오류 화면 확인'),
              ),
              PopupMenuItem(
                value: MovieLoadMode.timeout,
                child: Text('시간 초과 확인'),
              ),
            ],
          ),
      ],
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: ['전체', ...movieGenres]
                .map(
                  (genre) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('genreChip-$genre'),
                      label: Text(genre),
                      selected: genre == '전체'
                          ? _genres.isEmpty
                          : _genres.contains(genre),
                      onSelected: (_) =>
                          _selectGenres(genre == '전체' ? {} : {genre}),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text('정렬', style: TextStyle(color: AppColors.mutedText)),
              const SizedBox(width: 8),
              DropdownButton<MovieSort>(
                key: const Key('movieSort'),
                value: _sort,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                    value: MovieSort.original,
                    child: Text('기본순'),
                  ),
                  DropdownMenuItem(value: MovieSort.title, child: Text('제목순')),
                  DropdownMenuItem(value: MovieSort.rating, child: Text('평점순')),
                ],
                onChanged: (sort) {
                  if (sort == null) return;
                  setState(() {
                    _sort = sort;
                    _sortChanged = true;
                  });
                  _persist();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Movie>>(
            future: _moviesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const MovieListLoading();
              }
              if (snapshot.hasError) {
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: MovieListError(
                    onRetry: _reload,
                    timedOut: snapshot.error is TimeoutException,
                  ),
                );
              }
              final movies = _visibleMovies(snapshot.data ?? const <Movie>[]);
              if (movies.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: MovieListEmpty(
                    onReset: () {
                      _selectGenres({});
                      _reload();
                    },
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Text(
                      _genres.isEmpty
                          ? '전체 영화 ${movies.length}편'
                          : '${_genres.join(', ')} · ${movies.length}편',
                      style: const TextStyle(color: AppColors.mutedText),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _reload,
                      child: _isGrid
                          ? MovieGrid(movies: movies, onTap: _openDetail)
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                              itemCount: movies.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 24),
                              itemBuilder: (context, index) => MovieListTile(
                                movie: movies[index],
                                onTap: () => _openDetail(movies[index]),
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
