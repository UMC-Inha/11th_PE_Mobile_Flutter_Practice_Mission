import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_card.dart';
import 'package:movielog/widgets/tmdb_poster_image.dart';

/// 영화 목록의 리스트 보기에서 쓰는 한 줄 항목.
class MovieListTile extends StatelessWidget {
  const MovieListTile({
    super.key,
    required this.movie,
    required this.onTap,
    this.genreName,
  });

  final TmdbMovieDto movie;
  final VoidCallback onTap;
  final String? genreName;

  @override
  Widget build(BuildContext context) {
    final subtitle = [releaseYear(movie), genreName].whereType<String>();
    return GestureDetector(
      key: Key('movieTile-${movie.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TmdbPosterImage(
              posterPath: movie.posterPath,
              width: 64,
              height: 92,
              size: 'w185',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle.join(' · '),
                    style: const TextStyle(color: AppColors.mutedText),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    // TMDB 평점은 10점 만점이라 별 5개에 맞춰 반으로 나눈다.
                    RatingBarIndicator(
                      rating: movie.voteAverage / 2,
                      itemSize: 16,
                      itemBuilder: (context, _) => const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFF5B301),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      movie.voteAverage.toStringAsFixed(1),
                      style: const TextStyle(color: AppColors.mutedText),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.mutedText),
        ],
      ),
    );
  }
}
