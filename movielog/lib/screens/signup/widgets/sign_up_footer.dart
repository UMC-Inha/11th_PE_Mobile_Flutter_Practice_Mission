import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// 화면 하단의 로그인 이동 안내 문구입니다. 화면 이동은 3주차에 연결합니다.
class SignUpFooter extends StatelessWidget {
  const SignUpFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('이미 계정이 있나요? ', style: AppTextStyles.bodySmall),
        GestureDetector(
          onTap: () => debugPrint('로그인 화면으로 이동 버튼을 눌렀습니다.'),
          child: Text(
            '로그인',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.violet,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
