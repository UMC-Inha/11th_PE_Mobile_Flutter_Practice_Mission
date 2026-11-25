import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/tmdb_genre_dto.dart';
import '../../data/services/tmdb_movie_service.dart';
import '../../theme/app_colors.dart';
import '../../view_models/load_phase.dart';
import '../../view_models/paged_movies_view_model.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/movie_page_footer.dart';
import '../../widgets/search_action_button.dart';
import 'widgets/genre_chip_bar.dart';
import 'widgets/movie_grid.dart';
import 'widgets/movie_list_empty.dart';
import 'widgets/movie_list_error.dart';
import 'widgets/movie_list_loading.dart';

/// 영화 목록 화면입니다. 첫 page만 불러오고 "더 보기"로 다음 page를 이어 붙입니다.
/// 목록 상태와 API 호출은 [PagedMoviesViewModel]이 담당합니다.
class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  // build마다 새 요청을 만들지 않도록 장르 목록 요청은 한 번만 만듭니다.
  late final Future<List<TmdbGenreDto>> _genres = context
      .read<TmdbMovieService>()
      .fetchGenres();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(
        title: '영화',
        // 누르면 영화 검색 화면(/movies/search)으로 이동합니다.
        actions: [SearchActionButton(color: AppColors.darkGray)],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            FutureBuilder<List<TmdbGenreDto>>(
              future: _genres,
              builder: (context, snapshot) {
                // 장르 목록을 못 불러와도 '전체' Chip과 영화 목록은 그대로 사용합니다.
                final genres = snapshot.data ?? const <TmdbGenreDto>[];
                return Consumer<PagedMoviesViewModel>(
                  builder: (context, vm, _) => GenreChipBar(
                    genres: genres,
                    selectedGenreId: vm.genreId,
                    // 장르를 바꾸면 generation이 올라가 이전 장르의 늦은 응답은 무시됩니다.
                    onSelected: (genreId) {
                      if (genreId == vm.genreId) return;
                      vm.loadInitial(genreId: genreId);
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Consumer<PagedMoviesViewModel>(
                builder: (context, vm, child) {
                  return switch (vm.phase) {
                    LoadPhase.idle ||
                    LoadPhase.loading => const MovieListLoading(),
                    LoadPhase.error => MovieListError(
                      message: vm.errorMessage,
                      onRetry: vm.reload,
                    ),
                    LoadPhase.empty => const MovieListEmpty(),
                    LoadPhase.ready => MovieGrid(
                      movies: vm.movies,
                      footer: MoviePageFooter(vm: vm),
                    ),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
