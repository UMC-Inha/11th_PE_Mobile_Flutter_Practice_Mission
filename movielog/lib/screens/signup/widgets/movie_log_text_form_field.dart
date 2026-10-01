import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// 회원가입 화면의 입력창 3개(닉네임, 이메일, 비밀번호)가 공통으로 사용하는
/// TextFormField 래퍼입니다. Figma 디자인처럼 라벨을 입력창 위에 별도 Text로 두고,
/// 입력창 자체는 hint 문구만 보여줍니다.
class MovieLogTextFormField extends StatelessWidget {
  const MovieLogTextFormField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    this.focusNode,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final FocusNode? focusNode;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(labelText, style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTextStyles.bodySmall,
            filled: true,
            fillColor: AppColors.fieldFill,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.violet, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
          ),
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
        ),
      ],
    );
  }
}
