import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/favorite_list_item.dart';
import '../../data/models/tmdb_movie_dto.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../view_models/favorites_view_model.dart';
import '../../view_models/load_phase.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/movielog_button.dart';
import '../../widgets/tmdb_movie_card.dart';

/// 마이페이지 → 내 즐겨찾기 화면입니다.
/// 목록·빈 목록·조회 오류·영화 정보 한 건 실패를 서로 다른 화면으로 보여줍니다.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, required this.onOpenMovie});

  /// 상세 화면으로 이동하고, 돌아올 때까지 기다립니다.
  final Future<void> Function(TmdbMovieDto movie) onOpenMovie;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FavoritesViewModel>().refresh();
    });
  }

  Future<void> _open(FavoritesViewModel vm, TmdbMovieDto movie) async {
    await widget.onOpenMovie(movie);
    if (!mounted) return;
    // 상세에서 해제하고 돌아오면 목록을 다시 조회합니다.
    // ViewModel도 같은 현재 세션인지 다시 확인합니다.
    await vm.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '내 즐겨찾기',
        centerTitle: true,
        onBack: () => context.canPop() ? context.pop() : context.go('/my'),
      ),
      body: SafeArea(
        child: Consumer<FavoritesViewModel>(
          builder: (context, vm, _) {
            return switch (vm.phase) {
              LoadPhase.idle || LoadPhase.loading => const Center(
                child: CircularProgressIndicator(),
              ),
              LoadPhase.empty => RefreshIndicator(
                onRefresh: vm.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 160),
                    Icon(
                      Icons.bookmark_border,
                      size: 48,
                      color: AppColors.gray,
                    ),
                    SizedBox(height: 12),
                    Text('아직 즐겨찾기한 영화가 없습니다.', textAlign: TextAlign.center),
                  ],
                ),
              ),
              LoadPhase.error => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40),
                    const SizedBox(height: 12),
                    Text(vm.errorMessage ?? '조회 오류입니다.'),
                    const SizedBox(height: 16),
                    MovieLogButton(label: '다시 시도', onPressed: vm.refresh),
                  ],
                ),
              ),
              LoadPhase.ready => RefreshIndicator(
                onRefresh: vm.refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (vm.hasMissingMovie)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(
                            '일부 영화 정보를 불러오지 못했습니다. 카드의 재조회 버튼을 눌러 주세요.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.darkGray,
                            ),
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      sliver: SliverGrid.builder(
                        itemCount: vm.items.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 24,
                              childAspectRatio: 0.56,
                            ),
                        itemBuilder: (context, index) {
                          final item = vm.items[index];
                          final movie = item.movie;
                          if (movie == null) {
                            return _MissingMovieCard(
                              item: item,
                              onRetry: () =>
                                  vm.retryMovie(item.favorite.movieId),
                            );
                          }
                          // 기존 영화 카드를 그대로 사용하고, 탭 동작만 복귀 후 갱신으로 바꿉니다.
                          return TmdbMovieCard(
                            movie: movie,
                            onTap: () => _open(vm, movie),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            };
          },
        ),
      ),
    );
  }
}

/// TMDB 영화 정보를 가져오지 못한 즐겨찾기 카드입니다. 이 카드만 다시 조회합니다.
class _MissingMovieCard extends StatelessWidget {
  const _MissingMovieCard({required this.item, required this.onRetry});

  final FavoriteListItem item;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image_outlined, size: 36),
                const SizedBox(height: 8),
                Text(
                  item.errorMessage ?? '정보가 없습니다.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 12),
                MovieLogButton(
                  label: '정보 재조회',
                  isLoading: item.isRetrying,
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '영화 #${item.favorite.movieId}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
