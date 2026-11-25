import 'package:flutter/material.dart';

import '../../../data/models/rating_request.dart';
import '../../../data/services/rating_api_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/movie_rating_input.dart';
import '../../../widgets/movielog_button.dart';

/// 별점과 코멘트를 입력받아 [onSubmit]으로 저장하는 커스텀 Dialog입니다.
/// 평점 등록(영화 상세)과 수정(내가 등록한 평점)이 함께 사용합니다.
///
/// - [onSubmit]이 예외 없이 끝나면 true를 반환하며 닫힙니다.
/// - 취소하면 [onSubmit]을 호출하지 않고 false를 반환합니다.
/// - 저장에 실패하면 Dialog를 유지하고 입력값을 그대로 둔 채 오류를 보여줍니다.
class RatingDialog extends StatefulWidget {
  const RatingDialog({
    super.key,
    this.initialScore = 0,
    this.initialComment,
    required this.onSubmit,
  });

  /// 0이면 아직 별점을 선택하지 않은 상태입니다.
  final int initialScore;

  /// null이면 코멘트 입력칸이 빈 칸으로 시작합니다.
  final String? initialComment;
  final Future<void> Function(int score, String? comment) onSubmit;

  static const maxCommentLength = 500;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late int _score = widget.initialScore;

  // build마다 새로 만들면 setState 때 입력하던 코멘트가 사라지므로 State에서 한 번만 만듭니다.
  late final _commentController = TextEditingController(
    text: widget.initialComment ?? '',
  );
  bool _isSubmitting = false;
  String? _errorText;

  bool get _canSubmit => _score > 0 && !_isSubmitting;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _onConfirm() async {
    final trimmed = _commentController.text.trim();
    if (trimmed.length > RatingDialog.maxCommentLength) {
      setState(() => _errorText = '코멘트는 500자 이하로 입력해 주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      // 빈 문자열은 null로 바꿔 요청합니다.
      await widget.onSubmit(_score, trimmed.isEmpty ? null : trimmed);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      // 실패해도 로딩을 풀어 다시 시도할 수 있게 합니다. 입력값은 그대로 둡니다.
      setState(() {
        _isSubmitting = false;
        _errorText = error is RatingWriteException
            ? error.message
            : '저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 바깥 탭은 showDialog의 barrierDismissible: false가, 뒤로가기는 PopScope가 막습니다.
    return PopScope(
      canPop: !_isSubmitting,
      child: Dialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('영화는 어떠셨나요?', style: AppTextStyles.titleMedium),
              const SizedBox(height: 24),
              MovieRatingInput(
                rating: _score.toDouble(),
                enabled: !_isSubmitting,
                onChanged: (value) =>
                    setState(() => _score = validateServerScore(value)),
              ),
              const SizedBox(height: 12),
              Text(
                _score > 0 ? '$_score점' : '별점을 선택해주세요',
                style: _score > 0
                    ? AppTextStyles.titleMedium.copyWith(
                        color: AppColors.violet,
                      )
                    : AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                enabled: !_isSubmitting,
                maxLines: 3,
                maxLength: RatingDialog.maxCommentLength,
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: '코멘트를 남겨보세요 (선택)',
                  hintStyle: AppTextStyles.bodySmall,
                  filled: true,
                  fillColor: AppColors.fieldFill,
                  contentPadding: const EdgeInsets.all(12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.fieldBorder),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.fieldBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.violet,
                      width: 2,
                    ),
                  ),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 4),
                Text(
                  _errorText!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: MovieLogButton(
                      label: '취소',
                      width: double.infinity,
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MovieLogButton(
                      label: '확인',
                      width: double.infinity,
                      isLoading: _isSubmitting,
                      // 별점을 선택하기 전에는 코멘트가 있어도 확인할 수 없습니다.
                      onPressed: _canSubmit ? _onConfirm : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
