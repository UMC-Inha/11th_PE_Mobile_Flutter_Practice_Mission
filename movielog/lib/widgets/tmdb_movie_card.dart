import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'movie_card.dart';
import 'tmdb_movie_format.dart';
import 'tmdb_poster_image.dart';

/// TMDB 영화 DTO를 표시하는 카드입니다.
/// 카드를 누르면 TMDB `id`를 Path Parameter로, DTO를 extra로 넘겨 상세 화면을 push합니다.
class TmdbMovieCard extends StatelessWidget {
  const TmdbMovieCard({
    super.key,
    required this.movie,
    this.width,
  });

  final TmdbMovieDto movie;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final releaseYear = movie.releaseYear;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/movies/${movie.id}', extra: movie),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    TmdbPosterImage(
                      posterPath: movie.posterPath,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: RatingBadge(rating: movie.fivePointRating),
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
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            if (releaseYear != null) ...[
              const SizedBox(height: 2),
              Text(
                releaseYear,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.darkGray),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
