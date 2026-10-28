import 'package:flutter/material.dart';
import 'package:movielog/core/theme/app_theme.dart';

const retryDialogRetryKey = Key('retryDialogRetry');
const retryDialogCancelKey = Key('retryDialogCancel');

/// 최근 성공 목록을 유지한 채 요청이 실패했을 때 띄우는 Dialog.
/// "다시 시도"면 true, "취소"·바깥 탭이면 false.
Future<bool> showRetryDialog(BuildContext context, {String? message}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => RetryDialog(message: message),
  );
  return result ?? false;
}

class RetryDialog extends StatelessWidget {
  const RetryDialog({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFFF1EDFA),
              child: Icon(Icons.refresh, color: AppColors.primary, size: 30),
            ),
            const SizedBox(height: 16),
            const Text(
              '영화를 불러오지 못했어요',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message ?? '네트워크 상태를 확인하고\n다시 시도해 주세요.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    key: retryDialogCancelKey,
                    onPressed: () => Navigator.of(context).pop(false),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: retryDialogRetryKey,
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('다시 시도'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
