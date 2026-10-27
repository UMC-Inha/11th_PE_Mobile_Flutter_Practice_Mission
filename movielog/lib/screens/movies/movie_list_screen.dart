import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/movie.dart';
import '../../services/fake_movie_service.dart';
import '../../services/genre_preference.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/search_action_button.dart';
import 'widgets/genre_chip_bar.dart';
import 'widgets/movie_grid.dart';
import 'widgets/movie_list_empty.dart';
import 'widgets/movie_list_error.dart';
import 'widgets/movie_list_loading.dart';

/// 영화 목록과 저장된 장르를 함께 불러온 초기 데이터입니다.
class MovieListInitialData {
  const MovieListInitialData({
    required this.movies,
    required this.selectedGenre,
  });

  final List<Movie> movies;
  final String selectedGenre;
}

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key, this.selectedGenre});

  /// Router가 Query Parameter(`/movies?genre=SF`)에서 읽어 전달한 장르입니다.
  /// 없으면 로컬에 저장된 마지막 선택 장르를 사용합니다.
  final String? selectedGenre;

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  final _movieService = const FakeMovieService();
  final _genrePreference = GenrePreference();

  late Future<MovieListInitialData> _initialDataFuture;

  /// Query Parameter 또는 Chip으로 직접 선택한 장르입니다. null이면 저장된 장르를 따릅니다.
  String? _selectedGenre;

  /// Debug 실행에서 AppBar 메뉴로 바꿔 보는 로드 결과입니다. (재시도는 항상 success로 요청합니다.)
  MovieLoadMode _loadMode = MovieLoadMode.success;

  @override
  void initState() {
    super.initState();
    _selectedGenre = widget.selectedGenre;
    _initialDataFuture = _loadInitialData(mode: _loadMode);
  }

  Future<MovieListInitialData> _loadInitialData({
    MovieLoadMode mode = MovieLoadMode.success,
  }) async {
    try {
      // 두 작업은 서로 의존하지 않으므로 함께 시작합니다.
      final results = await Future.wait([
        _movieService.fetchMovies(mode: mode),
        _genrePreference.read(),
      ]);

      return MovieListInitialData(
        movies: results[0] as List<Movie>,
        selectedGenre: results[1] as String,
      );
    } on MovieLoadException catch (error, stackTrace) {
      debugPrint('영화 로드 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  void _retry() {
    setState(() {
      _loadMode = MovieLoadMode.success;
      _initialDataFuture = _loadInitialData();
    });
  }

  void _reloadWith(MovieLoadMode mode) {
    setState(() {
      _loadMode = mode;
      _initialDataFuture = _loadInitialData(mode: mode);
    });
  }

  Future<void> _selectGenre(String genre) async {
    setState(() {
      _selectedGenre = genre;
    });

    // 선택한 장르를 Query Parameter로 URL에 표현합니다. '전체'는 조건 없이 /movies로 이동합니다.
    final location = Uri(
      path: '/movies',
      queryParameters: genre == allGenreLabel ? null : {'genre': genre},
    ).toString();

    context.go(location);

    await _genrePreference.save(genre);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [
          // Loading·Empty·Error·Success 상태를 확인하기 위한 Debug 전용 메뉴입니다.
          if (kDebugMode)
            PopupMenuButton<MovieLoadMode>(
              tooltip: '로드 결과 바꾸기',
              icon: const Icon(Icons.bug_report_outlined,
                  color: AppColors.darkGray),
              initialValue: _loadMode,
              onSelected: _reloadWith,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: MovieLoadMode.success,
                  child: Text('성공'),
                ),
                PopupMenuItem(
                  value: MovieLoadMode.empty,
                  child: Text('빈 목록'),
                ),
                PopupMenuItem(
                  value: MovieLoadMode.failure,
                  child: Text('실패'),
                ),
              ],
            ),
          const SearchActionButton(color: AppColors.darkGray),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<MovieListInitialData>(
          future: _initialDataFuture,
          builder: (context, snapshot) {
            final selectedGenre = _selectedGenre ??
                snapshot.data?.selectedGenre ??
                allGenreLabel;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                GenreChipBar(
                  genres: movieGenres,
                  selectedGenre: selectedGenre,
                  onSelected: _selectGenre,
                ),
                const SizedBox(height: 16),
                Expanded(child: _buildContent(snapshot, selectedGenre)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    AsyncSnapshot<MovieListInitialData> snapshot,
    String selectedGenre,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const MovieListLoading();
    }

    if (snapshot.hasError) {
      return MovieListError(onRetry: _retry);
    }

    final movies = snapshot.data?.movies ?? const <Movie>[];
    final filteredMovies = selectedGenre == allGenreLabel
        ? movies
        : movies.where((movie) => movie.genre == selectedGenre).toList();

    if (filteredMovies.isEmpty) {
      return const MovieListEmpty();
    }

    return MovieGrid(movies: filteredMovies);
  }
}
