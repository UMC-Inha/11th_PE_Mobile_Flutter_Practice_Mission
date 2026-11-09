import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// 상세 화면 하단에 고정되는 즐겨찾기 / 평점 남기기 버튼 영역입니다.
class DetailActionBar extends StatelessWidget {
  const DetailActionBar({
    super.key,
    required this.isFavorite,
    required this.onFavoritePressed,
    required this.onRatePressed,
    this.notice,
  });

  final bool isFavorite;
  final VoidCallback onFavoritePressed;

  /// null이면 평점 남기기 버튼이 비활성화됩니다.
  final VoidCallback? onRatePressed;

  /// 버튼 위에 표시할 안내 문구입니다. (예: 회원가입 필요)
  final String? notice;

  static const _labelStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.warmWhite,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (notice != null) ...[
            Text(notice!, style: AppTextStyles.bodySmall),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: onFavoritePressed,
                    // 즐겨찾기 상태에 따라 아이콘이 바뀝니다.
                    icon: Icon(
                      isFavorite ? Icons.bookmark : Icons.bookmark_border,
                    ),
                    label: const Text('즐겨찾기'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.violet,
                      side: const BorderSide(color: AppColors.violet),
                      shape: const StadiumBorder(),
                      textStyle: _labelStyle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: onRatePressed,
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('평점 남기기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.violet,
                      foregroundColor: AppColors.white,
                      shape: const StadiumBorder(),
                      disabledBackgroundColor: AppColors.gray,
                      disabledForegroundColor: AppColors.white,
                      textStyle: _labelStyle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
