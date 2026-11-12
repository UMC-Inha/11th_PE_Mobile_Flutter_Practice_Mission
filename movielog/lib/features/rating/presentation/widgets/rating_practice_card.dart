import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:movielog/core/theme/app_theme.dart';

class RatingPracticeCard extends StatelessWidget {
  const RatingPracticeCard({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    required this.onSave,
  });

  final double rating;
  final ValueChanged<double> onRatingChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF1EDFA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '미니 실습 · 평점 입력',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              rating == 0
                  ? '별점을 선택해주세요.'
                  : '${rating.toStringAsFixed(1)}점을 선택했어요.',
              style: const TextStyle(color: AppColors.mutedText),
            ),
            const SizedBox(height: 16),
            RatingBar.builder(
              initialRating: rating,
              minRating: 1,
              allowHalfRating: true,
              itemCount: 5,
              itemPadding: const EdgeInsets.only(right: 4),
              itemBuilder: (context, _) =>
                  const Icon(Icons.star_rounded, color: Color(0xFFF5B301)),
              onRatingUpdate: onRatingChanged,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: rating > 0 ? onSave : null,
              child: const Text('평점 저장'),
            ),
          ],
        ),
      ),
    );
  }
}
