import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common_app_bar.dart';

/// 추가 미니 실습: flutter_rating_bar로 별점 입력 상태를 다룹니다.
/// 별점을 선택하지 않으면 저장 버튼이 비활성화됩니다.
class RatingPracticeScreen extends StatefulWidget {
  const RatingPracticeScreen({super.key});

  @override
  State<RatingPracticeScreen> createState() => _RatingPracticeScreenState();
}

class _RatingPracticeScreenState extends State<RatingPracticeScreen> {
  double _rating = 0;

  bool get _canSave => _rating > 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: '평점 남기기'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('이 영화의 평점을 선택해주세요', style: AppTextStyles.titleMedium),
              const SizedBox(height: 24),
              Center(
                child: RatingBar(
                  initialRating: _rating,
                  minRating: 0,
                  itemCount: 5,
                  itemSize: 40,
                  allowHalfRating: true,
                  glowColor: AppColors.violet,
                  ratingWidget: RatingWidget(
                    full: const Icon(Icons.star, color: AppColors.violet),
                    half: const Icon(Icons.star_half, color: AppColors.violet),
                    empty: const Icon(Icons.star_border, color: AppColors.gray),
                  ),
                  onRatingUpdate: (rating) => setState(() => _rating = rating),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  _rating == 0 ? '별점을 선택해주세요' : '선택한 평점: $_rating',
                  style: AppTextStyles.bodySmall,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _canSave
                      ? () => debugPrint('평점 $_rating점이 저장되었습니다.')
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    foregroundColor: AppColors.white,
                    disabledBackgroundColor: AppColors.gray.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('평점 저장'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
