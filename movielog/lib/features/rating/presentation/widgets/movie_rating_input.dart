import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

/// 별점 입력 위젯. 값은 부모가 들고 있고, 바뀔 때 onChanged로 알려준다.
class MovieRatingInput extends StatelessWidget {
  const MovieRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.itemSize = 40,
  });

  final double rating;
  final ValueChanged<double> onChanged;
  final double itemSize;

  @override
  Widget build(BuildContext context) {
    // RatingBar는 initialRating만 받으므로, 0으로 초기화될 때
    // Key를 바꿔 위젯을 새로 만들어 별도 함께 비운다.
    return KeyedSubtree(
      key: ValueKey(rating == 0),
      child: RatingBar.builder(
        initialRating: rating,
        minRating: 0.5,
        allowHalfRating: true,
        itemCount: 5,
        itemSize: itemSize,
        glow: false,
        itemPadding: const EdgeInsets.symmetric(horizontal: 2),
        itemBuilder: (context, _) =>
            const Icon(Icons.star_rounded, color: Color(0xFFF5B301)),
        onRatingUpdate: onChanged,
      ),
    );
  }
}
