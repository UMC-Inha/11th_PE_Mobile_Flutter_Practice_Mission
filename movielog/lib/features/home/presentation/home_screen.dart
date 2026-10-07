import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/core/data/mock_movies.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openDetail(BuildContext context, Movie movie) {
    // push: 상세에서 뒤로 가면 홈으로 돌아온다.
    context.push(AppRoutes.movieDetail(movie.id));
  }

  @override
  Widget build(BuildContext context) {
    final featured = mockMovies.first;
    final others = mockMovies.skip(1).toList();

    return Scaffold(
      appBar: AppBar(
        // 홈은 첫 화면이므로 뒤로 가기 버튼을 두지 않는다.
        automaticallyImplyLeading: false,
        title: const Text(
          'MovieLog',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _FeaturedBanner(
            movie: featured,
            onTap: () => _openDetail(context, featured),
          ),
          const SizedBox(height: 28),
          const _SectionTitle(title: '지금 많이 보는 영화'),
          const SizedBox(height: 12),
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: others.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final movie = others[index];
                return MovieCard(
                  movie: movie,
                  width: 130,
                  onTap: () => _openDetail(context, movie),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedBanner extends StatelessWidget {
  const _FeaturedBanner({required this.movie, required this.onTap});

  final Movie movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('featured-${movie.id}'),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(movie.posterPath, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
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
                    const Text(
                      '오늘의 추천',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      movie.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${movie.genre} · ${movie.year}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.text,
        fontSize: 19,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
