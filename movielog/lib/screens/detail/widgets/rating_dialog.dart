import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/movie_rating_input.dart';

/// MovieRatingInput을 담은 커스텀 Dialog입니다.
/// 확인을 누르면 선택한 별점을 showDialog의 반환값으로 돌려줍니다.
class RatingDialog extends StatefulWidget {
  const RatingDialog({super.key, this.initialRating = 0});

  final double initialRating;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late double _rating = widget.initialRating;

  bool get _canSubmit => _rating > 0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('영화는 어떠셨나요?', style: AppTextStyles.titleMedium),
            const SizedBox(height: 24),
            MovieRatingInput(
              rating: _rating,
              onChanged: (value) {
                setState(() {
                  _rating = value;
                });
              },
            ),
            const SizedBox(height: 12),
            Text(
              _canSubmit ? '$_rating점' : '별점을 선택해주세요',
              style: _canSubmit
                  ? AppTextStyles.titleMedium.copyWith(color: AppColors.violet)
                  : AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    // 별점을 선택하기 전에는 확인 버튼이 비활성화됩니다.
                    onPressed: _canSubmit ? () => Navigator.pop(context, _rating) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.violet,
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor: AppColors.violet.withValues(alpha: 0.35),
                      disabledForegroundColor: AppColors.white,
                    ),
                    child: const Text('확인'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
