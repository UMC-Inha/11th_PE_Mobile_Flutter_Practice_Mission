import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

class EditProfileButton extends StatelessWidget {
  const EditProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.violetDark,
          side: const BorderSide(color: AppColors.violetDark),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          '프로필 수정',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.violetDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
