import 'package:flutter/material.dart';

import '../../../data/models/rating_with_movie.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/tmdb_poster_image.dart';

/// 평점 하나를 TMDB 영화 제목·포스터와 함께 보여주는 카드입니다.
/// TMDB에서 영화를 찾지 못하면 placeholder를 보여주고 평점 기록은 그대로 유지합니다.
/// [onEdit]·[onDelete]는 본인이 작성한 평점일 때만 전달하며, 없으면 버튼을 그리지 않습니다.
class MyRatingCard extends StatelessWidget {
  const MyRatingCard({
    super.key,
    required this.entry,
    this.onEdit,
    this.onDelete,
  });

  final RatingWithMovie entry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final rating = entry.rating;
    final movie = entry.movie;
    final comment = rating.comment;
    final date = rating.createdAt.toLocal();
    final dateText =
        '${date.year}.${_twoDigits(date.month)}.${_twoDigits(date.day)}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lavenderLight,
        border: Border.all(color: AppColors.lavender),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            // movie가 null이면 posterPath도 null이라 포스터 placeholder가 표시됩니다.
            child: TmdbPosterImage(
              posterPath: movie?.posterPath,
              width: 64,
              height: 96,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie?.title ?? '영화 정보 없음',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: movie == null ? AppColors.gray : AppColors.black,
                  ),
                ),
                if (movie == null)
                  Text(
                    'movieId ${rating.movieId}',
                    style: AppTextStyles.bodySmall,
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: AppColors.violet,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${rating.score}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.violetDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                // 후기가 없으면(null) 표시하지 않습니다.
                if (comment != null && comment.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(comment, style: AppTextStyles.bodyMedium),
                ],
                const SizedBox(height: 4),
                Text(dateText, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          if (onEdit != null || onDelete != null) ...[
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEdit != null)
                  _CardActionButton(label: '수정', onPressed: onEdit!),
                if (onEdit != null && onDelete != null)
                  const SizedBox(height: 4),
                if (onDelete != null)
                  _CardActionButton(
                    label: '삭제',
                    color: AppColors.error,
                    onPressed: onDelete!,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

/// 카드 오른쪽의 작은 수정·삭제 버튼입니다.
class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.label,
    required this.onPressed,
    this.color = AppColors.violet,
  });

  final String label;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(56, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
