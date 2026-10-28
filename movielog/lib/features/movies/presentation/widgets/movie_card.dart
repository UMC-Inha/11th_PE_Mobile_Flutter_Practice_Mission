import 'package:flutter/material.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/widgets/tmdb_poster_image.dart';

/// "2024-05-01" → "2024". 개봉일이 없으면 null(연도를 표시하지 않는다).
String? releaseYear(TmdbMovieDto movie) {
  final date = movie.releaseDate;
  if (date == null || date.length < 4) return null;
  return date.substring(0, 4);
}

/// 포스터 + 평점 배지 + 제목 + 연도·장르를 보여주는 공통 영화 카드.
class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.movie,
    required this.onTap,
    this.width,
    this.genreName,
    this.rank,
  });

  final TmdbMovieDto movie;
  final VoidCallback onTap;
  final double? width;
  final String? genreName;

  /// 홈 인기 영역의 순위(1~5). null이면 표시하지 않는다.
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final subtitle = [releaseYear(movie), genreName].whereType<String>();
    return GestureDetector(
      key: Key('movieCard-${movie.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    TmdbPosterImage(posterPath: movie.posterPath, size: 'w342'),
                    if (rank != null)
                      Positioned(left: 8, top: 8, child: _Badge('$rank')),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: _Badge(
                        '★ ${movie.voteAverage.toStringAsFixed(1)}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              movie.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 13,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC2B2730),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
