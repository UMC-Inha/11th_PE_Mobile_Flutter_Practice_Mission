import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// 평균 평점(읽기 전용)과 평가 수, 내가 남긴 평점을 한 줄로 보여줍니다.
class MovieRatingSummary extends StatelessWidget {
  const MovieRatingSummary({
    super.key,
    required this.averageRating,
    required this.ratingCount,
    required this.myRating,
  });

  final double averageRating;
  final int ratingCount;
  final double? myRating;

  static String _formatCount(int count) {
    return count.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        RatingBarIndicator(
          rating: averageRating,
          itemCount: 5,
          itemSize: 22,
          unratedColor: AppColors.chipGray,
          itemBuilder: (context, index) {
            return const Icon(
              Icons.star,
              color: AppColors.violet,
            );
          },
        ),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: averageRating.toStringAsFixed(1),
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              ),
              TextSpan(
                text: ' (${_formatCount(ratingCount)})',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.darkGray),
              ),
            ],
          ),
        ),
        if (myRating != null)
          Text(
            '내 평점 $myRating',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.violet,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}
