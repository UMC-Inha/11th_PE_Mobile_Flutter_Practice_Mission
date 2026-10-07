import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/movie.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/movie_card.dart';

/// 섹션 제목과 가로 스크롤 영화 카드 목록입니다.
class MovieSection extends StatelessWidget {
  const MovieSection({
    super.key,
    required this.title,
    required this.movies,
  });

  final String title;
  final List<Movie> movies;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.titleLarge.copyWith(fontSize: 22),
                ),
              ),
              TextButton(
                // 탭 전환이므로 Stack에 쌓지 않고 go로 위치를 바꿉니다.
                onPressed: () => context.go('/movies'),
                style: TextButton.styleFrom(foregroundColor: AppColors.violetDark),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('전체보기', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 270,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: movies.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return MovieCard(movie: movies[index], width: 144);
            },
          ),
        ),
      ],
    );
  }
}
