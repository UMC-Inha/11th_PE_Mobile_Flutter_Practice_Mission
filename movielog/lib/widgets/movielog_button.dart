import 'package:flutter/material.dart';
import 'package:movielog/core/theme/app_theme.dart';

/// 화면과 상관없이 재사용하는 공용 버튼.
///
/// 상태 세 가지(기본·통신 중·비활성)와 너비 세 가지(내용 기반·최대·고정)를
/// 이 Widget 하나로 표현한다. 상태를 스스로 바꾸지 않고 View가 넘겨준 값만 그린다.
///
/// - 기본: [onPressed]가 있고 [isLoading]이 false
/// - 통신 중: [isLoading]이 true. [onPressed]와 상관없이 눌리지 않고 인디케이터만 보인다.
/// - 비활성: [onPressed]가 null
///
/// [width]
/// - null: label 길이에 맞는 내용 기반 크기(입력창 옆 보조 버튼)
/// - `double.infinity`: 부모가 허용하는 최대 너비(Form 아래 제출 버튼).
///   너비 제약이 없는 위치(제약 없는 Row 등)에서는 Expanded 같은 상위 Widget으로 먼저 감싼다.
/// - 고정 값: 주변과 상관없이 그 크기
class MovieLogButton extends StatelessWidget {
  const MovieLogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.width,
    this.height = defaultHeight,
  });

  static const defaultHeight = 44.0;

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final double height;

  bool get _disabled => isLoading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: _disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.disabled,
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // 통신 중에는 label과 인디케이터를 함께 그리지 않고 하나만 고른다.
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}
