import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../theme/app_colors.dart';

/// 사용자가 별 한 개 단위(1~5 정수)로 별점을 입력하는 Widget입니다.
/// v6 서버 평점은 정수이므로 반 점 입력을 막습니다.
/// RatingBar는 항상 double을 돌려주므로 값은 1.0, 2.0처럼 정수를 나타내는 double입니다.
class MovieRatingInput extends StatelessWidget {
  const MovieRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.enabled = true,
  });

  final double rating;
  final ValueChanged<double> onChanged;

  /// false면 저장 중처럼 별점을 바꿀 수 없습니다.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return RatingBar.builder(
      initialRating: rating,
      minRating: 1,
      allowHalfRating: false,
      ignoreGestures: !enabled,
      itemCount: 5,
      itemSize: 40,
      glow: false,
      itemBuilder: (context, index) {
        return const Icon(Icons.star, color: AppColors.violet);
      },
      onRatingUpdate: onChanged,
    );
  }
}
