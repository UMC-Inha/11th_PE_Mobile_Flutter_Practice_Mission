import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/load_phase.dart';
import '../view_models/paged_movies_view_model.dart';
import 'movielog_button.dart';

/// 목록 맨 아래의 더 보기 / 추가 로딩 / 같은 page 재시도 / 끝 상태입니다.
class MoviePageFooter extends StatelessWidget {
  const MoviePageFooter({super.key, required this.vm});

  final PagedMoviesViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (!vm.hasMore && !vm.isLoadingMore && vm.loadMoreError == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '더 이상 조회할 페이지가 없습니다.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.darkGray),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (vm.loadMoreError != null) ...[
            Text(
              vm.loadMoreError!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: 8),
          ],
          MovieLogButton(
            width: double.infinity,
            label: vm.loadMoreError == null ? '더 보기' : '다음 페이지 다시 시도',
            isLoading: vm.isLoadingMore,
            onPressed: vm.phase == LoadPhase.ready ? vm.loadNextPage : null,
          ),
        ],
      ),
    );
  }
}
