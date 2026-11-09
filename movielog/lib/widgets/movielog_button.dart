import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 여러 화면이 함께 쓰는 MovieLog 공용 버튼입니다.
///
/// 상태는 스스로 바꾸지 않고, 화면이 전달한 값만 그대로 표시합니다.
/// - 기본: [onPressed]가 있고 [isLoading]이 false
/// - 통신 중: [isLoading]이 true면 항상 비활성이고 가운데에 인디케이터만 표시
/// - 비활성: [onPressed]가 null
///
/// [width]는 null이면 내용 기반 크기, double.infinity면 부모가 허용하는 최대 너비,
/// 숫자면 그 값으로 고정됩니다.
class MovieLogButton extends StatelessWidget {
  const MovieLogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.width,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;

  bool get _disabled => isLoading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 44,
      child: ElevatedButton(
        onPressed: _disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.violet,
          disabledBackgroundColor: AppColors.gray,
          foregroundColor: AppColors.white,
          disabledForegroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // 통신 중에는 label과 인디케이터 중 하나만 그립니다.
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : Text(label, maxLines: 1, softWrap: false),
      ),
    );
  }
}
