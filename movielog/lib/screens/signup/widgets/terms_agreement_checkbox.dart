import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// 필수 약관 동의 Checkbox입니다. 글자를 눌러도 값이 바뀌도록 GestureDetector로 감쌉니다.
class TermsAgreementCheckbox extends StatelessWidget {
  const TermsAgreementCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: value,
          activeColor: AppColors.violet,
          onChanged: (checked) => onChanged(checked ?? false),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: const Text(
              '필수 약관에 동의합니다',
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}
