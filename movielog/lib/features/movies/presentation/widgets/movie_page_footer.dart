import 'package:flutter/material.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';
import 'package:movielog/widgets/movielog_button.dart';

const loadMoreButtonKey = Key('loadMoreButton');
const loadMoreRetryKey = Key('loadMoreRetry');
const loadMoreIndicatorKey = Key('loadMoreIndicator');
const loadMoreErrorKey = Key('loadMoreError');
const moviePageEndKey = Key('moviePageEnd');

/// 영화 목록·검색 결과 맨 아래에 붙는 footer. 네 가지 상태를 서로 다르게 보여 준다.
///
/// 1. 더 받을 page가 있다: "더 보기" 버튼
/// 2. 다음 page를 받는 중: 버튼을 비활성화하고 로딩을 표시(기존 목록은 그대로)
/// 3. 다음 page 조회에 실패했다: 오류 안내 + 같은 page를 다시 요청하는 버튼
/// 4. 마지막 page다: 끝 안내(더 보기 버튼 없음)
///
/// [autoLoad]가 true면(무한 스크롤) 1번의 버튼을 보여 주지 않는다. 스크롤이 끝에 가까워지면
/// 화면이 알아서 다음 page를 요청한다. 3번의 "다시 시도" 버튼은 그대로 남아, 오류가 났을 때
/// 같은 요청이 자동으로 반복되지 않고 사용자가 직접 다시 시도한다.
class MoviePageFooter extends StatelessWidget {
  const MoviePageFooter({super.key, required this.viewModel, this.autoLoad = false});

  final PagedMoviesViewModel viewModel;
  final bool autoLoad;

  @override
  Widget build(BuildContext context) {
    final error = viewModel.loadMoreError;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Column(
          children: [
            Text(
              error,
              key: loadMoreErrorKey,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
            const SizedBox(height: 8),
            MovieLogButton(
              key: loadMoreRetryKey,
              label: '다음 페이지 다시 시도',
              width: double.infinity,
              onPressed: viewModel.loadNextPage,
            ),
          ],
        ),
      );
    }
    if (viewModel.isLoadingMore) {
      if (autoLoad) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                key: loadMoreIndicatorKey,
                strokeWidth: 2.5,
              ),
            ),
          ),
        );
      }
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: MovieLogButton(
          key: loadMoreButtonKey,
          label: '더 보기',
          width: double.infinity,
          isLoading: true,
          onPressed: null,
        ),
      );
    }
    if (viewModel.hasMore) {
      if (autoLoad) return const SizedBox(height: 24);
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: MovieLogButton(
          key: loadMoreButtonKey,
          label: '더 보기',
          width: double.infinity,
          onPressed: viewModel.loadNextPage,
        ),
      );
    }
    return const Padding(
      key: moviePageEndKey,
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          '더 이상 불러올 영화가 없어요.',
          style: TextStyle(color: AppColors.mutedText),
        ),
      ),
    );
  }
}
