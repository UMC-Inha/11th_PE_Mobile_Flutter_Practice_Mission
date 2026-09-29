import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:movielog/core/data/mock_movies.dart';
import 'package:movielog/core/theme/app_theme.dart';

/// 영화 목록의 리스트 보기에서 쓰는 한 줄 항목.
class MovieListTile extends StatelessWidget {
  const MovieListTile({super.key, required this.movie, required this.onTap});

  final Movie movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('movieTile-${movie.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              movie.posterPath,
              width: 64,
              height: 92,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${movie.genre} · ${movie.year} · ${movie.runtimeMinutes}분',
                  style: const TextStyle(color: AppColors.mutedText),
                ),
                const SizedBox(height: 6),
                RatingBarIndicator(
                  rating: movie.averageRating,
                  itemSize: 16,
                  itemBuilder: (context, _) =>
                      const Icon(Icons.star_rounded, color: Color(0xFFF5B301)),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.mutedText),
        ],
      ),
    );
  }
}
