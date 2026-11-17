import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'theme/app_text_styles.dart';
import 'widgets/movielog_button.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

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
              // 1주차 StartScreen 하단의 '시작하기' ElevatedButton 자리를
              // 로딩/재시도 상태로 대체합니다.
              if (onRetry == null)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    Text(message ?? '로그인 상태를 확인하지 못했어요.'),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: MovieLogButton(
                        label: '다시 시도',
                        onPressed: onRetry,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
