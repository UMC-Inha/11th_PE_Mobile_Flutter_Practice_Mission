import 'package:flutter/material.dart';

import '../../../models/movie.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'movie_rating_summary.dart';

/// 상세 화면 상단의 포스터 이미지, 제목, 기본 정보, 평점, 태그 영역입니다.
class MovieDetailHeader extends StatelessWidget {
  const MovieDetailHeader({
    super.key,
    required this.movie,
    required this.myRating,
  });

  final Movie movie;
  final double? myRating;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 2 / 3,
          child: Image.asset(
            movie.posterAsset,
            fit: BoxFit.cover,
            alignment: movie.posterAlignment,
            semanticLabel: '${movie.title} 포스터',
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
              const SizedBox(height: 6),
              Text(
                '${movie.year} • ${movie.genres.join('/')} • ${movie.runtime}분',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.darkGray),
              ),
              const SizedBox(height: 12),
              MovieRatingSummary(
                averageRating: movie.averageRating,
                ratingCount: movie.ratingCount,
                myRating: myRating,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in movie.tags) _TagChip(label: tag),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.chipGray,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.darkGray,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
