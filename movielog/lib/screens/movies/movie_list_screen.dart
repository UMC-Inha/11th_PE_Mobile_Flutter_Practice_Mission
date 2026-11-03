import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../view_models/movie_list_view_model.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/search_action_button.dart';
import 'widgets/genre_chip_bar.dart';
import 'widgets/movie_grid.dart';
import 'widgets/movie_list_empty.dart';
import 'widgets/movie_list_error.dart';
import 'widgets/movie_list_loading.dart';

/// 영화 목록 화면입니다. 상태와 API 호출은 [MovieListViewModel]이 담당하고,
/// 이 화면은 상태를 그리고 사용자 입력을 ViewModel에 전달하기만 합니다.
class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(
        title: '영화',
        actions: [SearchActionButton(color: AppColors.darkGray)],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Consumer<MovieListViewModel>(
              builder: (context, viewModel, child) {
                return GenreChipBar(
                  genres: viewModel.genres,
                  selectedGenreId: viewModel.selectedGenreId,
                  enabled: viewModel.canChangeGenre,
                  onSelected: (genreId) =>
                      context.read<MovieListViewModel>().selectGenre(genreId),
                );
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Consumer<MovieListViewModel>(
                builder: (context, viewModel, child) {
                  return switch (viewModel.status) {
                    MovieListLoadStatus.idle ||
                    MovieListLoadStatus.loading => const MovieListLoading(),
                    MovieListLoadStatus.error => MovieListError(
                        message: viewModel.message,
                        onRetry: () =>
                            context.read<MovieListViewModel>().loadInitial(),
                      ),
                    MovieListLoadStatus.empty => const MovieListEmpty(),
                    MovieListLoadStatus.success => MovieGrid(
                        movies: viewModel.movies,
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
