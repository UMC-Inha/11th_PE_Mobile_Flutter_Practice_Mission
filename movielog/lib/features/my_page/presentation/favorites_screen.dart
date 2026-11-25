import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/data/models/favorite_list_item.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_list_tile.dart';
import 'package:movielog/view_models/favorites_view_model.dart';
import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:provider/provider.dart';

const favoritesLoadingKey = Key('favoritesLoading');
const favoritesEmptyKey = Key('favoritesEmpty');
const favoritesErrorKey = Key('favoritesError');
const favoritesRetryKey = Key('favoritesRetry');
const favoritesListKey = Key('favoritesList');

/// 마이페이지 → "내 즐겨찾기". 마이페이지 위에 열리는 자식 화면이라
/// 하단 NavigationBar 없이 AppBar의 BackButton으로 돌아간다.
///
/// 화면 상태 네 가지가 서로 다르다.
/// - 목록: 영화 카드(5주차 [MovieListTile] 재사용)
/// - 빈 목록: 요청은 성공했지만 즐겨찾기가 없다
/// - 조회 오류: 목록 조회 자체가 실패했다(다시 시도 버튼)
/// - 영화 정보 한 건 실패: 그 카드만 `영화 #{movieId}` placeholder와 다시 조회 버튼이고 나머지는 그대로
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    // 화면이 처음 만들어질 때 한 번 조회한다(build에서 조회하지 않는다).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FavoritesViewModel>().refresh();
    });
  }

  /// 카드를 눌러 상세로 간다. 상세에서 즐겨찾기를 해제하고 돌아오면 목록을 다시 조회해
  /// 해제한 영화가 사라지게 한다.
  Future<void> _openMovie(TmdbMovieDto movie) async {
    final viewModel = context.read<FavoritesViewModel>();
    await context.push(AppRoutes.movieDetail(movie.id), extra: movie);
    if (!mounted) return;
    await viewModel.refresh(); // ViewModel이 지금도 같은 세션인지 다시 확인한다.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.my),
        ),
        title: const Text(
          '내 즐겨찾기',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Consumer<FavoritesViewModel>(
        builder: (context, viewModel, _) => switch (viewModel.phase) {
          LoadPhase.idle || LoadPhase.loading => const Center(
            child: CircularProgressIndicator(key: favoritesLoadingKey),
          ),
          LoadPhase.empty => _stateMessage(
            key: favoritesEmptyKey,
            icon: Icons.bookmark_border,
            title: '아직 즐겨찾기한 영화가 없어요.',
            detail: '영화 상세의 북마크 버튼으로 즐겨찾기를 추가해 보세요.',
            onRefresh: viewModel.refresh,
          ),
          LoadPhase.error => _errorBody(viewModel),
          LoadPhase.ready => _list(viewModel),
        },
      ),
    );
  }

  Widget _stateMessage({
    required Key key,
    required IconData icon,
    required String title,
    required String detail,
    required Future<void> Function() onRefresh,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Column(
            key: key,
            children: [
              Icon(icon, size: 52, color: AppColors.mutedText),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(detail, style: const TextStyle(color: AppColors.mutedText)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errorBody(FavoritesViewModel viewModel) {
    return Center(
      key: favoritesErrorKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 52,
              color: AppColors.mutedText,
            ),
            const SizedBox(height: 16),
            const Text(
              '내 즐겨찾기를 불러오지 못했어요.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.errorMessage ?? '잠시 후 다시 시도해 주세요.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText),
            ),
            const SizedBox(height: 16),
            MovieLogButton(
              key: favoritesRetryKey,
              label: '다시 시도',
              onPressed: viewModel.refresh,
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(FavoritesViewModel viewModel) {
    final items = viewModel.items;
    return RefreshIndicator(
      onRefresh: viewModel.refresh,
      child: ListView.separated(
        key: favoritesListKey,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: items.length,
        separatorBuilder: (context, index) => const Divider(height: 24),
        itemBuilder: (context, index) {
          final item = items[index];
          final movie = item.movie;
          if (movie == null) {
            return _MissingMovieTile(
              item: item,
              isRetrying: viewModel.retryingMovieIds.contains(
                item.favorite.movieId,
              ),
              onRetry: () => viewModel.retryMovie(item.favorite.movieId),
            );
          }
          return MovieListTile(movie: movie, onTap: () => _openMovie(movie));
        },
      ),
    );
  }
}

/// TMDB에서 영화 정보를 가져오지 못한 한 건. 즐겨찾기 자체는 그대로 있으므로 지우지 않고
/// `영화 #{movieId}`로 보여 주며, 이 카드만 다시 조회할 수 있다.
class _MissingMovieTile extends StatelessWidget {
  const _MissingMovieTile({
    required this.item,
    required this.isRetrying,
    required this.onRetry,
  });

  final FavoriteListItem item;
  final bool isRetrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final movieId = item.favorite.movieId;
    return Row(
      key: Key('favoritePlaceholder-$movieId'),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 64,
            height: 92,
            color: const Color(0xFFEDEAF2),
            alignment: Alignment.center,
            child: const Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.mutedText,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '영화 #$movieId',
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.errorMessage ?? '영화 정보가 없어요.',
                style: const TextStyle(color: AppColors.mutedText),
              ),
              const SizedBox(height: 8),
              MovieLogButton(
                key: Key('favoriteRetryMovie-$movieId'),
                label: '영화 정보 다시 조회',
                height: 36,
                isLoading: isRetrying,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
