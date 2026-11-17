import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_card.dart';
import 'package:movielog/features/rating/presentation/widgets/movie_rating_dialog.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/widgets/tmdb_poster_image.dart';
import 'package:provider/provider.dart';

const favoriteButtonKey = Key('favoriteButton');
const rateButtonKey = Key('rateButton');
const tmdbIdLabelKey = Key('tmdbIdLabel');

class MovieDetailScreen extends StatelessWidget {
  const MovieDetailScreen({super.key});

  Future<void> _rate(
    BuildContext context,
    MovieDetailViewModel viewModel,
  ) async {
    final movie = viewModel.movie!;
    final score = await showMovieRatingDialog(
      context,
      movieTitle: movie.title,
      initialRating: (viewModel.myRating?.score ?? 0).toDouble(),
    );
    if (score == null || !context.mounted) return;
    // 평점 요청의 movieId = TMDB id (배열 index가 아니다)
    final request = viewModel.rate(score.round());
    debugPrint('[평점 요청 준비] ${request.toJson()}');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'movieId ${request.movieId}에 ${request.score}점을 남겼어요. '
            '(서버 저장은 6주차)',
          ),
        ),
      );
  }

  void _toggleFavorite(BuildContext context, MovieDetailViewModel viewModel) {
    viewModel.toggleFavorite();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            viewModel.isFavorite ? '즐겨찾기에 추가했어요.' : '즐겨찾기에서 삭제했어요.',
          ),
          action: SnackBarAction(
            label: '되돌리기',
            onPressed: viewModel.toggleFavorite,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MovieDetailViewModel>();
    final movie = viewModel.movie;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/movies'),
        ),
        actions: [
          if (movie != null)
            IconButton(
              key: favoriteButtonKey,
              tooltip: viewModel.isFavorite ? '즐겨찾기 삭제' : '즐겨찾기 추가',
              onPressed: () => _toggleFavorite(context, viewModel),
              icon: Icon(
                viewModel.isFavorite ? Icons.bookmark : Icons.bookmark_border,
                color: viewModel.isFavorite ? AppColors.primary : null,
              ),
            ),
        ],
      ),
      body: switch (viewModel.status) {
        MovieDetailLoadStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        MovieDetailLoadStatus.error => Center(
          child: Text(viewModel.message ?? '영화를 찾을 수 없어요.'),
        ),
        MovieDetailLoadStatus.success => ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            _PosterHeader(movie: movie!),
            const SizedBox(height: 24),
            _AverageRating(voteAverage: movie.voteAverage),
            const SizedBox(height: 20),
            const Text(
              '줄거리',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (movie.overview.trim().isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    '줄거리 정보가 없어요.',
                    style: TextStyle(color: AppColors.mutedText),
                  ),
                ),
              )
            else
              Text(
                movie.overview,
                style: const TextStyle(color: AppColors.text, height: 1.6),
              ),
            const SizedBox(height: 28),
            if (viewModel.myRating != null) ...[
              Text(
                '내 평점 ${viewModel.myRating!.score}점',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
            ],
            FilledButton.icon(
              key: rateButtonKey,
              onPressed: () => _rate(context, viewModel),
              icon: const Icon(Icons.star_rounded),
              label: Text(viewModel.myRating == null ? '평점 남기기' : '평점 수정하기'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'TMDB 영화 ID ${movie.id}',
              key: tmdbIdLabelKey,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
          ],
        ),
      },
    );
  }
}

class _PosterHeader extends StatelessWidget {
  const _PosterHeader({required this.movie});

  final TmdbMovieDto movie;

  @override
  Widget build(BuildContext context) {
    final year = releaseYear(movie);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: TmdbPosterImage(
            posterPath: movie.posterPath,
            height: 360,
            width: double.infinity,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          movie.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        // 개봉일이 없으면 연도를 표시하지 않는다.
        if (year != null) ...[
          const SizedBox(height: 6),
          Text('$year 개봉', style: const TextStyle(color: AppColors.mutedText)),
        ],
      ],
    );
  }
}

class _AverageRating extends StatelessWidget {
  const _AverageRating({required this.voteAverage});

  /// TMDB 10점 만점 평균
  final double voteAverage;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF1EDFA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TMDB 평균',
                    style: TextStyle(
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 10점 만점을 별 5개에 맞춰 반으로 나눈다.
                  RatingBarIndicator(
                    rating: voteAverage / 2,
                    itemSize: 22,
                    itemBuilder: (context, _) => const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF5B301),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              voteAverage.toStringAsFixed(1),
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(' / 10', style: TextStyle(color: AppColors.mutedText)),
          ],
        ),
      ),
    );
  }
}
