import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_card.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/widgets/tmdb_poster_image.dart';
import 'package:provider/provider.dart';

const homeRetryButtonKey = Key('homeRetryButton');

/// 홈 View. Popular 앞 5개(MovieHomeViewModel)를 그린다.
/// Popular 요청은 Route에서 ViewModel을 만들 때 한 번만 하고, build마다 반복하지 않는다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openDetail(BuildContext context, TmdbMovieDto movie) {
    // push: 상세에서 뒤로 가면 홈으로 돌아온다. TMDB id를 Path로 넘긴다.
    context.push(AppRoutes.movieDetail(movie.id), extra: movie);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'MovieLog',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Consumer<MovieHomeViewModel>(
        builder: (context, viewModel, _) {
          return switch (viewModel.status) {
            MovieHomeLoadStatus.idle ||
            MovieHomeLoadStatus.loading => const _HomeLoading(),
            MovieHomeLoadStatus.error => _HomeMessage(
              icon: Icons.cloud_off_outlined,
              title: '인기 영화를 불러오지 못했어요',
              message: viewModel.message,
              onRetry: viewModel.loadPopular,
            ),
            MovieHomeLoadStatus.empty => _HomeMessage(
              icon: Icons.movie_outlined,
              title: '지금은 인기 영화가 없어요',
              onRetry: viewModel.loadPopular,
            ),
            MovieHomeLoadStatus.success => _HomeContent(
              movies: viewModel.popularMovies,
              onOpen: (movie) => _openDetail(context, movie),
            ),
          };
        },
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.movies, required this.onOpen});

  final List<TmdbMovieDto> movies;
  final ValueChanged<TmdbMovieDto> onOpen;

  @override
  Widget build(BuildContext context) {
    final featured = movies.first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        const Text(
          '오늘은 어떤\n영화를 볼까요?',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 28,
            height: 1.25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 20),
        _FeaturedBanner(movie: featured, onTap: () => onOpen(featured)),
        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(
              child: Text(
                '인기 영화',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.movies),
              child: const Text('전체보기 ›'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 250,
          child: ListView.separated(
            key: const Key('popularList'),
            scrollDirection: Axis.horizontal,
            itemCount: movies.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) => MovieCard(
              movie: movies[index],
              rank: index + 1,
              width: 140,
              onTap: () => onOpen(movies[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeaturedBanner extends StatelessWidget {
  const _FeaturedBanner({required this.movie, required this.onTap});

  final TmdbMovieDto movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final year = releaseYear(movie);
    return ClipRRect(
      key: Key('featured-${movie.id}'),
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            TmdbPosterImage(posterPath: movie.posterPath),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xE6000000)],
                  stops: [0.45, 1],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        '인기 1위',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      ?year,
                      '★ ${movie.voteAverage.toStringAsFixed(1)}',
                    ].join(' · '),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.info),
                    label: const Text('상세보기'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    Widget block({double? width, double? height, double radius = 12}) =>
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFE8ECF2),
            borderRadius: BorderRadius.circular(radius),
          ),
        );
    return Semantics(
      label: '인기 영화를 불러오는 중',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          block(width: 180, height: 28),
          const SizedBox(height: 10),
          block(width: 140, height: 28),
          const SizedBox(height: 20),
          AspectRatio(aspectRatio: 4 / 5, child: block(radius: 24)),
          const SizedBox(height: 28),
          block(width: 100, height: 22),
        ],
      ),
    );
  }
}

class _HomeMessage extends StatelessWidget {
  const _HomeMessage({
    required this.icon,
    required this.title,
    required this.onRetry,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.mutedText),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.mutedText),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: homeRetryButtonKey,
              onPressed: onRetry,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
