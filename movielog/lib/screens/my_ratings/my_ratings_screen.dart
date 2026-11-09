import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/rating_dto.dart';
import '../../data/services/rating_api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../view_models/my_ratings_view_model.dart';
import '../../widgets/movielog_button.dart';
import '../detail/widgets/rating_dialog.dart';
import 'widgets/my_rating_card.dart';

/// 마이페이지 위에 열리는 "내가 등록한 평점" 자식 화면입니다.
/// root Navigator에 표시되므로 하단 NavigationBar가 없습니다.
class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: AppColors.violet),
        centerTitle: true,
        title: Text(
          '내가 등록한 평점',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.violet),
        ),
      ),
      body: SafeArea(
        child: Consumer<MyRatingsViewModel>(
          builder: (context, viewModel, child) {
            return switch (viewModel.status) {
              MyRatingsLoadStatus.idle ||
              MyRatingsLoadStatus.loading => const _RatingsLoading(),
              MyRatingsLoadStatus.empty => const _RatingsEmpty(),
              // 저장은 성공했지만 재조회만 실패했다면 그 사실을 따로 안내하고 GET만 다시 시도합니다.
              MyRatingsLoadStatus.error => _RatingsError(
                message:
                    viewModel.refreshWarning ??
                    viewModel.message ??
                    '평점을 불러오지 못했습니다.',
                onRetry: viewModel.load,
              ),
              MyRatingsLoadStatus.success => _RatingsList(viewModel: viewModel),
            };
          },
        ),
      ),
    );
  }
}

class _RatingsLoading extends StatelessWidget {
  const _RatingsLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _RatingsEmpty extends StatelessWidget {
  const _RatingsEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star_outline_rounded,
            size: 48,
            color: AppColors.gray,
          ),
          const SizedBox(height: 12),
          Text('아직 등록된 평점이 없어요.', style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

class _RatingsError extends StatelessWidget {
  const _RatingsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            // 화면 가운데의 단독 버튼이므로 고정 너비를 사용합니다.
            MovieLogButton(label: '다시 시도', width: 120, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _RatingsList extends StatelessWidget {
  const _RatingsList({required this.viewModel});

  final MyRatingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final message = viewModel.message;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '학습용 회원(memberId ${viewModel.memberId})이 등록한 평점입니다.',
          style: AppTextStyles.bodySmall,
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
          ),
        ],
        const SizedBox(height: 16),
        for (final entry in viewModel.ratings) ...[
          // 이 목록은 현재 학습용 회원의 평점만 조회하므로 모두 본인이 작성한 평점입니다.
          MyRatingCard(
            entry: entry,
            onEdit: () => _onEditPressed(context, viewModel, entry.rating),
            onDelete: () => _onDeletePressed(context, viewModel, entry.rating),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}

/// 기존 별점·코멘트를 채운 RatingDialog를 열어 수정합니다.
/// Dialog 안에서 값을 바꾸는 동안 실제 rating 객체는 바뀌지 않으므로 취소 시 복구할 것이 없습니다.
Future<void> _onEditPressed(
  BuildContext context,
  MyRatingsViewModel viewModel,
  RatingDto rating,
) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막습니다.
    builder: (_) => RatingDialog(
      initialScore: rating.score,
      initialComment: rating.comment, // null이면 빈 칸으로 시작합니다.
      onSubmit: (score, comment) => viewModel.updateRating(
        ratingId: rating.ratingId,
        score: score,
        comment: comment,
      ),
    ),
  );
  if (!context.mounted || saved != true) return;
  _showSnackBar(context, '평점을 수정했어요.');
}

/// 되돌릴 수 없는 삭제이므로 확인 Dialog를 거칩니다. 취소하면 요청을 보내지 않습니다.
Future<void> _onDeletePressed(
  BuildContext context,
  MyRatingsViewModel viewModel,
  RatingDto rating,
) async {
  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // 삭제 중 바깥 탭으로 닫히는 것도 막습니다.
    builder: (_) => _DeleteRatingDialog(
      onConfirm: () => viewModel.deleteRating(rating.ratingId),
    ),
  );
  // deleted는 실제로 삭제까지 마쳤을 때만 true입니다.
  if (!context.mounted || deleted != true) return;
  _showSnackBar(context, '평점을 삭제했어요.');
}

class _DeleteRatingDialog extends StatefulWidget {
  const _DeleteRatingDialog({required this.onConfirm});

  final Future<void> Function() onConfirm;

  @override
  State<_DeleteRatingDialog> createState() => _DeleteRatingDialogState();
}

class _DeleteRatingDialogState extends State<_DeleteRatingDialog> {
  bool _isDeleting = false;

  Future<void> _onConfirm() async {
    setState(() => _isDeleting = true);
    try {
      await widget.onConfirm();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      // 실패하면 Dialog를 유지해 다시 시도하거나 취소할 수 있게 둡니다.
      _showSnackBar(
        context,
        error is RatingWriteException
            ? error.message
            : '삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDeleting,
      child: Dialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('평점을 삭제할까요?', style: AppTextStyles.titleMedium),
              const SizedBox(height: 12),
              Text(
                '삭제한 평점은 복구할 수 없습니다.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.darkGray,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: MovieLogButton(
                      label: '취소',
                      width: double.infinity,
                      onPressed: _isDeleting
                          ? null
                          : () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MovieLogButton(
                      label: '삭제',
                      width: double.infinity,
                      isLoading: _isDeleting,
                      onPressed: _isDeleting ? null : _onConfirm,
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
