import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'theme/app_colors.dart';
import 'theme/app_text_styles.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  const SizedBox(height: 96),
                  // 0주차의 기본 Icon 자리에 MovieLog 로고 SVG를 표시합니다.
                  SvgPicture.asset(
                    'assets/logos/movielog_logo.svg',
                    width: 72,
                    height: 72,
                    semanticsLabel: 'MovieLog 로고',
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    '영화의 순간을\n기록하세요',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '보고 싶은 영화부터 나만의 평점까지\n한곳에서 관리해요',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  // go로 위치를 교체해 회원가입 화면에서 시작 화면으로 돌아갈 수 없게 합니다.
                  // Router.neglect는 웹 브라우저 히스토리에도 남기지 않습니다.
                  onPressed: () => Router.neglect(context, () => context.go('/register')),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    backgroundColor: AppColors.violet,
                    foregroundColor: AppColors.white,
                  ),
                  child: const Text('시작하기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
