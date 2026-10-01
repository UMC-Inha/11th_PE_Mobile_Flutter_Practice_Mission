import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// 가입하기 버튼입니다. enabled가 false면 onPressed를 null로 넘겨 비활성화합니다.
class SignUpSubmitButton extends StatelessWidget {
  const SignUpSubmitButton({
    super.key,
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.violet,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.violet.withValues(alpha: 0.35),
          disabledForegroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          '가입하기',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.white),
        ),
      ),
    );
  }
}
