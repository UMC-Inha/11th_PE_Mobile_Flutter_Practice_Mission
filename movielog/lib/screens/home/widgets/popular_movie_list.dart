import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_colors.dart';
import '../../../view_models/movie_home_view_model.dart';
import '../../../widgets/tmdb_movie_card.dart';

/// 홈의 인기 영화 가로 목록입니다. [MovieHomeViewModel]의 상태만 구독해 이 영역만 다시 그립니다.
class PopularMovieList extends StatelessWidget {
  const PopularMovieList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MovieHomeViewModel>(
      builder: (context, viewModel, child) {
        return switch (viewModel.status) {
          MovieHomeLoadStatus.idle ||
          MovieHomeLoadStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
          MovieHomeLoadStatus.error => _PopularMovieError(
              message: viewModel.message,
              onRetry: () => context.read<MovieHomeViewModel>().loadPopular(),
            ),
          MovieHomeLoadStatus.empty => const Center(
              child: Text('인기 영화가 없어요.'),
            ),
          MovieHomeLoadStatus.success => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: viewModel.popularMovies.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return TmdbMovieCard(
                  movie: viewModel.popularMovies[index],
                  width: 144,
                );
              },
            ),
        };
      },
    );
  }
}

class _PopularMovieError extends StatelessWidget {
  const _PopularMovieError({this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.darkGray),
          const SizedBox(height: 8),
          Text(message ?? '인기 영화를 불러오지 못했어요.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}
