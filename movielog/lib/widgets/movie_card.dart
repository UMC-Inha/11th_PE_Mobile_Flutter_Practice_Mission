import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/movie.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 홈의 가로 목록과 영화 목록 Grid에서 함께 사용하는 영화 카드입니다.
/// 카드를 누르면 Path Parameter(영화 ID)로 상세 화면을 push합니다.
class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.movie,
    this.width,
  });

  final Movie movie;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Path Parameter로 ID를 전달하고, 이미 가진 Movie 객체는 extra로 함께 넘깁니다.
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
                    Image.asset(
                      movie.posterAsset,
                      fit: BoxFit.cover,
                      alignment: movie.posterAlignment,
                      semanticLabel: '${movie.title} 포스터',
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _RatingBadge(rating: movie.averageRating),
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
            const SizedBox(height: 2),
            Text(
              '${movie.year} · ${movie.genre}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.darkGray),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xB3303030),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 14, color: AppColors.white),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}
