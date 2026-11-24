import 'package:flutter/material.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/view_models/favorite_detail_view_model.dart';
import 'package:provider/provider.dart';

const favoriteButtonKey = Key('favoriteButton');
const favoriteProgressKey = Key('favoriteProgress');
const favoriteReloadKey = Key('favoriteReload');

/// 영화 상세 제목 오른쪽의 북마크 버튼.
///
/// - 서버 성공을 확인한 뒤에야 아이콘이 바뀐다(요청 중에는 북마크 자리에 로딩만 보인다).
/// - 첫 여부 조회·등록·해제 중에는 버튼이 비활성화된다.
/// - 결과는 Snackbar로 안내한다. 실패하면 이전 아이콘 그대로다.
/// - 첫 여부 조회에 실패했을 때만 새로고침 버튼으로 바뀐다(여부를 모르는 채 등록·해제하지 않는다).
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key});

  static const _size = 52.0;

  Future<void> _toggle(
    BuildContext context,
    FavoriteDetailViewModel viewModel,
  ) async {
    final result = await viewModel.toggle();
    if (!context.mounted) return;
    final message = switch (result) {
      FavoriteToggleResult.added => '즐겨찾기에 추가했어요.',
      FavoriteToggleResult.removed => '즐겨찾기에서 삭제했어요.',
      FavoriteToggleResult.alreadyAdded => '이미 즐겨찾기에 있는 영화예요.',
      FavoriteToggleResult.alreadyRemoved => '이미 즐겨찾기에서 삭제된 영화예요.',
      FavoriteToggleResult.failed =>
        viewModel.errorMessage ?? '즐겨찾기를 처리하지 못했어요.',
      // 요청 중·세션 종료는 따로 안내하지 않는다(만료는 로그인 화면이 안내한다).
      FavoriteToggleResult.ignored => null,
    };
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoriteDetailViewModel>(
      builder: (context, viewModel, _) {
        final busy = viewModel.isLoading || viewModel.isSaving;
        if (!busy && !viewModel.hasLoadedStatus) {
          // 첫 여부 조회에 실패했다. 다시 확인할 수 있게 새로고침을 보여 준다.
          return SizedBox.square(
            dimension: _size,
            child: IconButton(
              key: favoriteReloadKey,
              tooltip: '즐겨찾기 상태 다시 확인',
              color: AppColors.primary,
              onPressed: viewModel.load,
              icon: const Icon(Icons.refresh),
            ),
          );
        }
        return SizedBox.square(
          dimension: _size,
          child: IconButton(
            key: favoriteButtonKey,
            tooltip: busy
                ? '즐겨찾기 처리 중'
                : viewModel.isFavorite
                ? '즐겨찾기 해제'
                : '즐겨찾기 추가',
            color: AppColors.primary,
            // 요청 중에는 비활성화한다(중복 탭 방지).
            onPressed: busy ? null : () => _toggle(context, viewModel),
            icon: busy
                // 북마크 자리에만 로딩을 보여 준다. 아이콘은 서버 응답 뒤에 바뀐다.
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      key: favoriteProgressKey,
                      strokeWidth: 2.5,
                    ),
                  )
                : Icon(
                    viewModel.isFavorite
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                  ),
          ),
        );
      },
    );
  }
}
