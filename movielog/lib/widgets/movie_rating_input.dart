import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../theme/app_colors.dart';

/// 사용자가 0.5점 단위로 별점을 입력하는 Widget입니다.
/// 실제 별점 값은 부모 Widget이 상태로 관리합니다.
class MovieRatingInput extends StatelessWidget {
  const MovieRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
  });

  final double rating;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return RatingBar.builder(
      initialRating: rating,
      minRating: 0.5,
      allowHalfRating: true,
      itemCount: 5,
      itemSize: 40,
      glow: false,
      itemBuilder: (context, index) {
        return const Icon(
          Icons.star,
          color: AppColors.violet,
        );
      },
      onRatingUpdate: onChanged,
    );
  }
}
