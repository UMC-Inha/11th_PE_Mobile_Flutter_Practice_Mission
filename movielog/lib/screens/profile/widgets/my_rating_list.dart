import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/member_rating_dto.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../view_models/my_ratings_view_model.dart';

/// 서버에서 받아온 내 평점 기록을 보여주는 프로필 섹션입니다.
class MyRatingList extends StatelessWidget {
  const MyRatingList({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MyRatingsViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '내 평점 기록',
          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        switch (viewModel.status) {
          MyRatingsLoadStatus.idle ||
          MyRatingsLoadStatus.loading =>
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
          MyRatingsLoadStatus.empty => Text(
              '아직 남긴 평점이 없어요.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.gray),
            ),
          MyRatingsLoadStatus.error => Row(
              children: [
                Expanded(
                  child: Text(
                    viewModel.message ?? '평점 기록을 불러오지 못했어요.',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                  ),
                ),
                TextButton(
                  onPressed: viewModel.load,
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          MyRatingsLoadStatus.success => Column(
              children: [
                for (final rating in viewModel.ratings) ...[
                  _RatingTile(rating: rating),
                  const SizedBox(height: 8),
                ],
              ],
            ),
        },
      ],
    );
  }
}

class _RatingTile extends StatelessWidget {
  const _RatingTile({required this.rating});

  final MemberRatingDto rating;

  @override
  Widget build(BuildContext context) {
    final date = rating.createdAt;
    final dateText =
        '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    final comment = rating.comment;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lavenderLight,
        border: Border.all(color: AppColors.lavender),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '영화 #${rating.movieId}',
                  style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.star_rounded, color: AppColors.violet, size: 20),
              const SizedBox(width: 4),
              Text(
                '${rating.score}',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.violetDark),
              ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comment, style: AppTextStyles.bodyMedium),
          ],
          const SizedBox(height: 8),
          Text(
            dateText,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.gray),
          ),
        ],
      ),
    );
  }
}
