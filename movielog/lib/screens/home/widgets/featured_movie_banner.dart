import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/movie.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// 홈 상단의 추천 신작 카드입니다. 카드나 상세보기 버튼을 누르면 상세로 push합니다.
class FeaturedMovieBanner extends StatelessWidget {
  const FeaturedMovieBanner({super.key, required this.movie});

  final Movie movie;

  // Path Parameter로 ID를 전달하고, 이미 가진 Movie 객체는 extra로 함께 넘깁니다.
  void _openDetail(BuildContext context) {
    context.push('/movies/${movie.id}', extra: movie);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openDetail(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  movie.posterAsset,
                  fit: BoxFit.cover,
                  alignment: movie.posterAlignment,
                  semanticLabel: '${movie.title} 포스터',
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66000000), Color(0x33000000), Color(0xE6000000)],
                      stops: [0, 0.45, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.violetDark,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.violet),
                        ),
                        child: Text(
                          '추천 신작',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        movie.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleLarge.copyWith(
                          fontSize: 28,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${movie.genres.join(' · ')} · ${movie.runtime}분',
                        style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xCCFFFFFF)),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () => _openDetail(context),
                          icon: const Icon(Icons.info),
                          label: const Text('상세보기'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.violetDark,
                            foregroundColor: AppColors.white,
                            shape: const StadiumBorder(),
                            textStyle: AppTextStyles.titleMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
