import 'package:flutter/material.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

/// 입력칸 아래에 붙는 "중복 확인" 버튼과 결과 문구.
class DuplicateCheckRow extends StatelessWidget {
  const DuplicateCheckRow({
    super.key,
    required this.buttonKey,
    required this.state,
    required this.enabled,
    required this.onCheck,
  });

  final Key buttonKey;
  final DuplicateCheckState state;

  /// 형식 검사를 통과해야 서버에 묻는다(백엔드도 형식이 틀리면 400).
  final bool enabled;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final checking = state.status == DuplicateCheckStatus.checking;
    final color = switch (state.status) {
      DuplicateCheckStatus.available => const Color(0xFF1B7F3B),
      DuplicateCheckStatus.taken ||
      DuplicateCheckStatus.failed => AppColors.error,
      _ => AppColors.mutedText,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              state.message ?? '가입 전에 중복 확인이 필요해요.',
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
          OutlinedButton(
            key: buttonKey,
            onPressed: enabled && !checking ? onCheck : null,
            child: checking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('중복 확인'),
          ),
        ],
      ),
    );
  }
}
