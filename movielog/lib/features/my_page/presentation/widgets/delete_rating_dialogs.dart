import 'package:flutter/material.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/view_models/submit_status.dart';
import 'package:movielog/widgets/movielog_button.dart';

const deleteRatingConfirmKey = Key('deleteRatingConfirm');
const deleteRatingCancelKey = Key('deleteRatingCancel');
const deleteRatingErrorKey = Key('deleteRatingError');
const deleteRatingPopScopeKey = Key('deleteRatingPopScope');
const deleteSelectedConfirmKey = Key('deleteSelectedConfirm');
const deleteSelectedCancelKey = Key('deleteSelectedCancel');

/// 평점 하나를 지우기 전에 확인한다. 삭제는 되돌릴 수 없어 확인 없이 바로 실행하지 않는다.
///
/// - 취소하면 [onConfirm]을 부르지 않고 false를 돌려주므로 삭제 요청이 나가지 않는다.
/// - 삭제 요청 중에는 Dialog가 유지되고 닫히지 않는다(PopScope + barrierDismissible: false).
/// - 요청이 끝까지 성공했을 때만 true를 돌려준다. 실패하면 사유를 보여주고 다시 시도할 수 있다.
Future<bool?> showDeleteRatingDialog(
  BuildContext context, {
  required Future<void> Function() onConfirm,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DeleteRatingDialog(onConfirm: onConfirm),
  );
}

class _DeleteRatingDialog extends StatefulWidget {
  const _DeleteRatingDialog({required this.onConfirm});

  final Future<void> Function() onConfirm;

  @override
  State<_DeleteRatingDialog> createState() => _DeleteRatingDialogState();
}

class _DeleteRatingDialogState extends State<_DeleteRatingDialog> {
  bool _isDeleting = false;
  String? _errorText;

  Future<void> _onConfirm() async {
    if (_isDeleting) return;
    setState(() {
      _isDeleting = true;
      _errorText = null;
    });
    try {
      await widget.onConfirm();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      // 실패하면 로딩을 풀어 다시 시도할 수 있게 한다.
      setState(() {
        _isDeleting = false;
        _errorText = error is RatingSaveException
            ? error.message
            : '삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      key: deleteRatingPopScopeKey,
      canPop: !_isDeleting,
      child: AlertDialog(
        title: const Text('평점을 삭제할까요?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('삭제한 평점은 복구할 수 없습니다.'),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                key: deleteRatingErrorKey,
                style: const TextStyle(color: AppColors.error),
              ),
            ],
          ],
        ),
        actions: [
          OutlinedButton(
            key: deleteRatingCancelKey,
            onPressed: _isDeleting
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          MovieLogButton(
            key: deleteRatingConfirmKey,
            label: '삭제',
            isLoading: _isDeleting,
            onPressed: _isDeleting ? null : _onConfirm,
          ),
        ],
      ),
    );
  }
}

/// 선택한 평점 N개를 지울지만 묻는다. 확인하면 Dialog는 **바로 닫히고**, 그 뒤 삭제 요청과
/// 로딩 오버레이는 화면(MyRatingsScreen)이 이어받는다. 단건 삭제와 달리 요청 중에 Dialog를
/// 붙잡아 두지 않는다.
Future<bool?> showDeleteSelectedConfirmDialog(
  BuildContext context, {
  required int count,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('선택한 $count개의 평점을 삭제할까요?'),
      content: const Text('삭제한 평점은 복구할 수 없습니다.'),
      actions: [
        TextButton(
          key: deleteSelectedCancelKey,
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('취소'),
        ),
        TextButton(
          key: deleteSelectedConfirmKey,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
}
