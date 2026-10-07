import 'package:flutter/material.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/features/rating/presentation/widgets/movie_rating_input.dart';

const saveRatingButtonKey = Key('saveRatingButton');
const resetRatingButtonKey = Key('resetRatingButton');

/// 평점 남기기 커스텀 Dialog를 띄운다. 저장하면 평점을, 취소하면 null을 돌려준다.
Future<double?> showMovieRatingDialog(
  BuildContext context, {
  required String movieTitle,
  double initialRating = 0,
}) {
  return showDialog<double>(
    context: context,
    builder: (context) =>
        MovieRatingDialog(movieTitle: movieTitle, initialRating: initialRating),
  );
}

class MovieRatingDialog extends StatefulWidget {
  const MovieRatingDialog({
    super.key,
    required this.movieTitle,
    required this.initialRating,
  });

  final String movieTitle;
  final double initialRating;

  @override
  State<MovieRatingDialog> createState() => _MovieRatingDialogState();
}

class _MovieRatingDialogState extends State<MovieRatingDialog> {
  late double _rating = widget.initialRating;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '평점 남기기',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.movieTitle,
              style: const TextStyle(color: AppColors.mutedText),
            ),
            const SizedBox(height: 20),
            MovieRatingInput(
              rating: _rating,
              onChanged: (value) => setState(() => _rating = value),
            ),
            const SizedBox(height: 10),
            Text(
              _rating == 0
                  ? '별을 눌러 평점을 선택하세요'
                  : '${_rating.toStringAsFixed(1)}점',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            // Challenge: 평점 초기화 후 다시 선택하기
            TextButton.icon(
              key: resetRatingButtonKey,
              onPressed: _rating == 0
                  ? null
                  : () => setState(() => _rating = 0),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('초기화하고 다시 선택'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: saveRatingButtonKey,
                    // 평점을 고르기 전에는 저장 버튼이 비활성화된다.
                    onPressed: _rating == 0
                        ? null
                        : () => Navigator.of(context).pop(_rating),
                    child: const Text('저장'),
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
