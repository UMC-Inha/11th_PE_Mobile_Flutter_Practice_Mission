import 'package:flutter/material.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/widgets/movielog_button.dart';

const splashIndicatorKey = Key('splashIndicator');
const splashMessageKey = Key('splashMessage');
const splashRetryKey = Key('splashRetry');

/// 앱을 켠 직후 저장된 토큰을 확인하는 동안 보이는 시작 화면(0주차 시작 화면 레이아웃 재사용).
///
/// 저장소를 확인하기 전에 로그인이나 홈을 잠깐 보여주면 화면이 튀고 보호 화면이 노출될 수 있다.
/// 그래서 확인하는 동안에는 빈 화면이 아니라 이 화면을 유지한다.
/// - [onRetry]가 null: 확인 중(initializing). 하단에 인디케이터
/// - [onRetry]가 있음: 확인하지 못한 상태(retryRequired). [message]와 다시 시도 버튼
///   (이때 저장된 토큰은 지우지 않았다.)
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Image.asset(
                  'assets/logos/movielog_logo.png',
                  width: 120,
                  height: 120,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'MovieLog',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '내가 본 영화를 기록하고\n나만의 영화 취향을 찾아보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              if (onRetry == null)
                const Center(
                  child: CircularProgressIndicator(key: splashIndicatorKey),
                )
              else ...[
                Text(
                  message ?? '로그인 상태를 확인하지 못했어요.',
                  key: splashMessageKey,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.mutedText),
                ),
                const SizedBox(height: 12),
                MovieLogButton(
                  key: splashRetryKey,
                  label: '다시 시도',
                  width: double.infinity,
                  height: 52,
                  onPressed: onRetry,
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
