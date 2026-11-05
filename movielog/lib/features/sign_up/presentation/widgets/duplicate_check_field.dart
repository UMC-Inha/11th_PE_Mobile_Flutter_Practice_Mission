import 'package:flutter/material.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/features/sign_up/presentation/widgets/movie_log_text_form_field.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:movielog/widgets/movielog_button.dart';

/// 입력창 바깥 오른쪽에 "중복 확인" 버튼이 붙는 입력칸.
///
/// [MovieLogTextFormField]와 [MovieLogButton]을 Row의 별도 형제로 두고 8px 띄운다.
/// 확인 결과(체크 표시)는 입력창 안쪽에만 그려서 버튼과 겹치지 않는다.
class DuplicateCheckField extends StatelessWidget {
  const DuplicateCheckField({
    super.key,
    required this.fieldKey,
    required this.buttonKey,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    required this.validator,
    required this.status,
    required this.errorText,
    required this.canCheck,
    required this.availableMessage,
    required this.onChanged,
    required this.onCheck,
    this.focusNode,
    this.keyboardType,
    this.onSubmitted,
  });

  final Key fieldKey;
  final Key buttonKey;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?) validator;

  final CheckStatus status;
  final String? errorText;

  /// ViewModel이 허용하는지(통신 중·이미 중복이면 false). 형식 검사는 아래에서 따로 한다.
  final bool canCheck;
  final String availableMessage;
  final VoidCallback onChanged;
  final VoidCallback onCheck;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final available = status == CheckStatus.available;
    final checking = status == CheckStatus.checking;
    // 형식이 틀린 값은 서버에 묻지 않는다(백엔드도 형식이 틀리면 400).
    final formatValid = validator(controller.text) == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          // 입력창에 에러 문구가 붙어 높이가 커져도 버튼은 입력 상자 높이에 맞춰 위쪽에 둔다.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: MovieLogTextFormField(
                fieldKey: fieldKey,
                controller: controller,
                focusNode: focusNode,
                label: label,
                hint: hint,
                prefixIcon: prefixIcon,
                keyboardType: keyboardType,
                textInputAction: TextInputAction.next,
                validator: validator,
                errorText: errorText,
                suffixIcon: available
                    ? const Icon(Icons.check_circle, color: AppColors.success)
                    : null,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
              ),
            ),
            const SizedBox(width: 8),
            // width를 주지 않아 label 길이에 맞는 내용 기반 크기를 쓴다.
            MovieLogButton(
              key: buttonKey,
              label: '중복 확인',
              height: 56,
              isLoading: checking,
              onPressed: canCheck && formatValid ? onCheck : null,
            ),
          ],
        ),
        if (available)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              availableMessage,
              style: const TextStyle(color: AppColors.success, fontSize: 13),
            ),
          ),
      ],
    );
  }
}
