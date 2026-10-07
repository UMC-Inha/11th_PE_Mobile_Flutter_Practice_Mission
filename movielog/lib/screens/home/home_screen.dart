import 'package:flutter/material.dart';

import '../../models/movie.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/search_action_button.dart';
import 'widgets/featured_movie_banner.dart';
import 'widgets/movie_section.dart';

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
            // 홈·목록·상세가 같은 Mock Data(ID 1)를 사용합니다.
            FeaturedMovieBanner(movie: movies.first),
            const SizedBox(height: 32),
            MovieSection(title: '인기 영화', movies: popularMovies),
          ],
        ),
      ),
    );
  }
}
