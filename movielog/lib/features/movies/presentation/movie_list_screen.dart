import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/core/storage/genre_preference.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/features/movies/presentation/widgets/genre_filter_sheet.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_grid.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_list_states.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_list_tile.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_page_footer.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';
import 'package:provider/provider.dart';

const filterButtonKey = Key('filterButton');
const viewModeButtonKey = Key('viewModeButton');
const movieSearchButtonKey = Key('movieSearchButton');
const allGenreChipKey = Key('genreChip-all');

/// 영화 목록 View. 상태를 직접 만들지 않고 MovieListViewModel을 그대로 그린다.
/// 남은 화면 상태는 격자/리스트 보기 전환과 스크롤 위치(무한 스크롤)뿐이다.
///
/// 첫 page를 보여 주고, 스크롤이 끝에 가까워지면([loadMoreThreshold] 이하) 다음 page를 이어 붙인다.
/// 중복 요청은 ViewModel이 막고, 다음 page 조회가 실패하면 footer의 "다시 시도" 버튼이 남아
/// 같은 요청이 자동으로 반복되지 않는다.
class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  /// 남은 스크롤 길이가 이 값(논리 픽셀) 이하이면 다음 page를 요청한다.
  static const loadMoreThreshold = 300.0;

  bool _isGrid = true;

  // 격자와 리스트가 번갈아 쓰는 하나의 컨트롤러. 화면이 사라질 때 리스너를 떼고 dispose한다.
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// 스크롤이 끝에 가까우면 다음 page를 요청한다. 격자↔리스트가 바뀌는 프레임에는 위치가 둘일 수
  /// 있어 하나일 때만 읽는다.
  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    final positions = _scrollController.positions;
    if (positions.length != 1) return;
    if (positions.first.extentAfter > loadMoreThreshold) return;
    _loadNextPageIfIdle();
  }

  /// 자동 요청 조건. 요청 중이거나 더 받을 page가 없으면 아무것도 하지 않고(ViewModel도 막는다),
  /// 직전 요청이 실패했다면 자동으로 반복하지 않는다(사용자가 footer의 "다시 시도"를 누른다).
  void _loadNextPageIfIdle() {
    final paged = context.read<MovieListViewModel>().paged;
    if (paged.loadMoreError != null || paged.isLoadingMore || !paged.hasMore) {
      return;
    }
    paged.loadNextPage();
  }

  /// 한 page가 화면을 다 채우지 못해 스크롤할 수 없는 경우를 위해, 그릴 때마다 끝에 가까운지 다시 본다.
  void _checkAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  Future<void> _openFilter(MovieListViewModel viewModel) async {
    final result = await showGenreFilterSheet(
      context,
      genres: viewModel.genres,
      initialSelection: viewModel.selectedGenreIds,
    );
    if (result == null || !mounted) return;
    await viewModel.selectGenres(result);
  }

  void _openDetail(TmdbMovieDto movie) {
    // 배열 index가 아니라 TMDB id를 Path로 넘긴다. 이 id가 평점의 movieId가 된다.
    context.push(AppRoutes.movieDetail(movie.id), extra: movie);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          '영화',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            key: viewModeButtonKey,
            tooltip: _isGrid ? '리스트로 보기' : '격자로 보기',
            onPressed: () => setState(() => _isGrid = !_isGrid),
            icon: Icon(_isGrid ? Icons.view_list : Icons.grid_view),
          ),
          // 필터 버튼만 따로 다시 그린다.
          Consumer<MovieListViewModel>(
            builder: (context, viewModel, _) => IconButton(
              key: filterButtonKey,
              tooltip: '장르 필터',
              onPressed: viewModel.canChangeGenre && viewModel.genres.isNotEmpty
                  ? () => _openFilter(viewModel)
                  : null,
              icon: Badge(
                isLabelVisible: viewModel.selectedGenreIds.isNotEmpty,
                label: Text('${viewModel.selectedGenreIds.length}'),
                child: const Icon(Icons.filter_list),
              ),
            ),
          ),
          // 검색 화면(/movies/search)은 하단 NavigationBar 위로 새로 열린다.
          IconButton(
            key: movieSearchButtonKey,
            tooltip: '영화 검색',
            onPressed: () => context.push(AppRoutes.movieSearch),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: Consumer<MovieListViewModel>(
        builder: (context, viewModel, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GenreChips(viewModel: viewModel),
            const SizedBox(height: 2),
            Expanded(child: _body(viewModel)),
          ],
        ),
      ),
    );
  }

  Widget _body(MovieListViewModel viewModel) {
    return switch (viewModel.status) {
      MovieListLoadStatus.idle ||
      MovieListLoadStatus.loading => const MovieListLoading(),
      MovieListLoadStatus.error => MovieListError(
        message: viewModel.message,
        timedOut: viewModel.timedOut,
        onRetry: viewModel.refresh,
      ),
      MovieListLoadStatus.empty => _refreshable(
        viewModel,
        MovieListEmpty(onReset: () => viewModel.selectGenres(null)),
      ),
      MovieListLoadStatus.success => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SortRow(viewModel: viewModel),
          Expanded(child: _refreshable(viewModel, _movies(viewModel))),
        ],
      ),
    };
  }

  /// Pull to Refresh. 현재 장르를 유지한 채 page 1부터 다시 받는다.
  /// 처음 받는 중에는 제스처를 받지 않는다.
  Widget _refreshable(MovieListViewModel viewModel, Widget child) {
    return RefreshIndicator(
      key: const Key('movieRefresh'),
      notificationPredicate: (notification) =>
          !viewModel.paged.isLoadingFirstPage &&
          defaultScrollNotificationPredicate(notification),
      onRefresh: viewModel.refresh,
      child: child,
    );
  }

  Widget _movies(MovieListViewModel viewModel) {
    final movies = viewModel.visibleMovies;
    // 무한 스크롤: "더 보기" 버튼 없이 로딩·오류("다시 시도")·끝 안내만 보여 준다.
    final footer = MoviePageFooter(viewModel: viewModel.paged, autoLoad: true);
    _checkAfterBuild();
    if (_isGrid) {
      return MovieGrid(
        movies: movies,
        onTap: _openDetail,
        genreNameOf: viewModel.primaryGenreName,
        controller: _scrollController,
        footer: footer,
      );
    }
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: movies.length + 1,
      separatorBuilder: (context, index) => const Divider(height: 24),
      itemBuilder: (context, index) {
        if (index == movies.length) return footer;
        return MovieListTile(
          movie: movies[index],
          genreName: viewModel.primaryGenreName(movies[index]),
          onTap: () => _openDetail(movies[index]),
        );
      },
    );
  }
}

class _GenreChips extends StatelessWidget {
  const _GenreChips({required this.viewModel});

  final MovieListViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    // 장르 목록을 받는 중에는 Chip을 눌러도 바뀌지 않게 onSelected를 끈다.
    // 영화 page를 받는 중에는 바꿀 수 있다(이전 장르의 늦은 응답은 ViewModel이 버린다).
    final enabled = viewModel.canChangeGenre;
    final selected = viewModel.selectedGenreIds;
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              key: allGenreChipKey,
              label: const Text('전체'),
              selected: selected.isEmpty,
              onSelected: enabled ? (_) => viewModel.selectGenre(null) : null,
            ),
          ),
          for (final genre in viewModel.genres)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('genreChip-${genre.id}'),
                label: Text(genre.name),
                selected: selected.contains(genre.id),
                onSelected: enabled
                    ? (_) => viewModel.selectGenre(genre.id)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({required this.viewModel});

  final MovieListViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${viewModel.selectionLabel} · ${viewModel.movies.length}편',
              key: const Key('movieCountLabel'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.mutedText),
            ),
          ),
          DropdownButton<MovieSort>(
            key: const Key('movieSort'),
            value: viewModel.sort,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: MovieSort.original, child: Text('인기순')),
              DropdownMenuItem(value: MovieSort.title, child: Text('제목순')),
              DropdownMenuItem(value: MovieSort.rating, child: Text('평점순')),
            ],
            onChanged: (sort) {
              if (sort != null) viewModel.setSort(sort);
            },
          ),
        ],
      ),
    );
  }
}
