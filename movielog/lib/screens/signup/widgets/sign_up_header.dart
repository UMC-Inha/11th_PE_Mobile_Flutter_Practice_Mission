import 'package:flutter/material.dart';

import '../../../theme/app_text_styles.dart';

/// 회원가입 화면 상단의 환영 문구입니다. 제목(회원가입)은 AppBar에서 이미 보여주므로
/// 본문에서는 중복하지 않고 환영 인사만 가운데 정렬로 보여줍니다.
class SignUpHeader extends StatelessWidget {
  const SignUpHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          '환영합니다!',
          textAlign: TextAlign.center,
          style: AppTextStyles.titleLarge,
        ),
        SizedBox(height: 8),
        Text(
          '간단한 정보만 입력하고 시작해보세요.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall,
        ),
      ],
    );
  }
}
