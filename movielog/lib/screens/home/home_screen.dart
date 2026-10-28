import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../view_models/movie_home_view_model.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/search_action_button.dart';
import 'widgets/featured_movie_banner.dart';
import 'widgets/movie_section.dart';
import 'widgets/popular_movie_list.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(
        title: 'MovieLog',
        actions: [SearchActionButton(color: AppColors.violet)],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '오늘은 어떤\n영화를 볼까요?',
                style: AppTextStyles.titleLarge.copyWith(fontSize: 28, height: 1.35),
              ),
            ),
            const SizedBox(height: 24),
            // 추천 배너는 인기 영화 1위를 보여주고, 불러오기 전·실패 시에는 숨깁니다.
            Consumer<MovieHomeViewModel>(
              builder: (context, viewModel, child) {
                if (viewModel.status != MovieHomeLoadStatus.success) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: FeaturedMovieBanner(movie: viewModel.popularMovies.first),
                );
              },
            ),
            // 인기 영화는 TMDB Popular 결과의 앞 5개를 사용합니다.
            const MovieSection(title: '인기 영화', child: PopularMovieList()),
          ],
        ),
      ),
    );
  }
}
