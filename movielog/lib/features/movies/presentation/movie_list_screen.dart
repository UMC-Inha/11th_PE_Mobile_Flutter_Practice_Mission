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
/// 남은 화면 상태는 격자/리스트 보기 전환 하나뿐이다.
///
/// 첫 page만 보여 주고, 맨 아래 footer의 "더 보기"로 다음 page를 이어 붙인다.
class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  bool _isGrid = true;

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
    final footer = MoviePageFooter(viewModel: viewModel.paged);
    if (_isGrid) {
      return MovieGrid(
        movies: movies,
        onTap: _openDetail,
        genreNameOf: viewModel.primaryGenreName,
        footer: footer,
      );
    }
    return ListView.separated(
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
