import 'package:flutter/material.dart';
import 'package:movielog/core/data/mock_movies.dart';
import 'package:movielog/core/theme/app_theme.dart';

/// 포스터 + 제목 + 장르·연도를 보여주는 공통 영화 카드.
/// 홈과 영화 목록(Grid)에서 함께 사용한다.
class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.movie,
    required this.onTap,
    this.width,
  });

  final Movie movie;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('movieCard-${movie.id}'),
      // 카드의 빈 공간을 눌러도 Tap이 잡히도록 한다.
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: double.infinity,
                  child: Image.asset(movie.posterPath, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              movie.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${movie.genre} · ${movie.year}',
              style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
