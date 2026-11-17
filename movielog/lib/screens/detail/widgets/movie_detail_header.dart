import 'package:flutter/material.dart';

import '../../../data/models/tmdb_movie_dto.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/tmdb_movie_format.dart';
import '../../../widgets/tmdb_poster_image.dart';
import 'movie_rating_summary.dart';

/// 상세 화면 상단의 포스터 이미지, 제목, 개봉 연도, 평점 영역입니다.
class MovieDetailHeader extends StatelessWidget {
  const MovieDetailHeader({
    super.key,
    required this.movie,
    required this.myRating,
  });

  final TmdbMovieDto movie;
  final double? myRating;

  @override
  Widget build(BuildContext context) {
    final releaseYear = movie.releaseYear;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 2 / 3,
          child: TmdbPosterImage(
            posterPath: movie.posterPath,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                movie.title,
                style: AppTextStyles.titleLarge.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // release_date가 없으면 개봉 연도를 표시하지 않습니다.
              if (releaseYear != null) ...[
                const SizedBox(height: 6),
                Text(
                  releaseYear,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.darkGray),
                ),
              ],
              const SizedBox(height: 12),
              MovieRatingSummary(
                averageRating: movie.fivePointRating,
                myRating: myRating,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
