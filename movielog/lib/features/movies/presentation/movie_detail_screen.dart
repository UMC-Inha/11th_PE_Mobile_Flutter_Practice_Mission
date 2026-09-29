import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/core/data/mock_movies.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/features/rating/presentation/widgets/movie_rating_dialog.dart';

const favoriteButtonKey = Key('favoriteButton');
const rateButtonKey = Key('rateButton');

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movieId});

  /// Route의 Path Parameter(`/movies/:movieId`)로 받은 영화 ID.
  final String? movieId;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  // 평점과 즐겨찾기는 서버 없이 이 화면 안의 상태로만 관리한다.
  bool _isFavorite = false;
  double _myRating = 0;

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_isFavorite ? '즐겨찾기에 추가했어요.' : '즐겨찾기에서 삭제했어요.'),
          action: SnackBarAction(
            label: '되돌리기',
            onPressed: () => setState(() => _isFavorite = !_isFavorite),
          ),
        ),
      );
  }

  Future<void> _rate(Movie movie) async {
    final rating = await showMovieRatingDialog(
      context,
      movieTitle: movie.title,
      initialRating: _myRating,
    );
    if (rating == null || !mounted) return;
    setState(() => _myRating = rating);
    // Dialog가 닫힌 뒤 현재 Scaffold에 Snackbar를 띄운다.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${rating.toStringAsFixed(1)}점으로 평점을 남겼어요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final movie = findMovieById(widget.movieId);
    if (movie == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('영화를 찾을 수 없어요.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          IconButton(
            key: favoriteButtonKey,
            tooltip: _isFavorite ? '즐겨찾기 삭제' : '즐겨찾기 추가',
            onPressed: _toggleFavorite,
            icon: Icon(
              _isFavorite ? Icons.bookmark : Icons.bookmark_border,
              color: _isFavorite ? AppColors.primary : null,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          _PosterHeader(movie: movie),
          const SizedBox(height: 24),
          _AverageRating(rating: movie.averageRating),
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
          Text(
            movie.overview,
            style: const TextStyle(color: AppColors.text, height: 1.6),
          ),
          const SizedBox(height: 28),
          if (_myRating > 0) ...[
            Text(
              '내 평점 ${_myRating.toStringAsFixed(1)}점',
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
            onPressed: () => _rate(movie),
            icon: const Icon(Icons.star_rounded),
            label: Text(_myRating == 0 ? '평점 남기기' : '평점 수정하기'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterHeader extends StatelessWidget {
  const _PosterHeader({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            movie.posterPath,
            height: 360,
            width: double.infinity,
            fit: BoxFit.cover,
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
        const SizedBox(height: 6),
        Text(
          '${movie.genre} · ${movie.year} · ${movie.runtimeMinutes}분',
          style: const TextStyle(color: AppColors.mutedText),
        ),
      ],
    );
  }
}

class _AverageRating extends StatelessWidget {
  const _AverageRating({required this.rating});

  final double rating;

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
            const Text(
              '평균 평점',
              style: TextStyle(
                color: AppColors.mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            // 읽기 전용 별점: 누를 수 없다.
            RatingBarIndicator(
              rating: rating,
              itemSize: 22,
              itemBuilder: (context, _) =>
                  const Icon(Icons.star_rounded, color: Color(0xFFF5B301)),
            ),
            const SizedBox(width: 8),
            Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
