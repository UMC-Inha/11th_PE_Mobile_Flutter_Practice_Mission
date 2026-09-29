import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/core/data/mock_movies.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/features/movies/presentation/widgets/genre_filter_sheet.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_card.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_list_tile.dart';

const filterButtonKey = Key('filterButton');
const viewModeButtonKey = Key('viewModeButton');

/// 영화 목록.
///
/// 선택한 장르는 화면 상태가 아니라 URL의 Query Parameter
/// (`/movies?genres=SF,드라마`)로 들고 있어서, 주소만으로 같은 목록을 다시 연다.
class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key, required this.selectedGenres});

  final Set<String> selectedGenres;

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  bool _isGrid = true;

  Future<void> _openFilter() async {
    final result = await showGenreFilterSheet(
      context,
      initialSelection: widget.selectedGenres,
    );
    // 확인 버튼 없이 닫으면(null) 기존 필터를 그대로 둔다.
    if (result == null || !mounted) return;
    context.go(moviesLocation(result));
  }

  void _openDetail(Movie movie) {
    context.push(AppRoutes.movieDetail(movie.id));
  }

  @override
  Widget build(BuildContext context) {
    final movies = filterMoviesByGenres(widget.selectedGenres);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('영화', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            key: viewModeButtonKey,
            tooltip: _isGrid ? '리스트로 보기' : '격자로 보기',
            onPressed: () => setState(() => _isGrid = !_isGrid),
            icon: Icon(_isGrid ? Icons.view_list : Icons.grid_view),
          ),
          IconButton(
            key: filterButtonKey,
            tooltip: '장르 필터',
            onPressed: _openFilter,
            icon: Badge(
              isLabelVisible: widget.selectedGenres.isNotEmpty,
              label: Text('${widget.selectedGenres.length}'),
              child: const Icon(Icons.filter_list),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterSummary(
            selectedGenres: widget.selectedGenres,
            count: movies.length,
            onClear: () => context.go(AppRoutes.movies),
          ),
          Expanded(
            child: movies.isEmpty
                ? const Center(child: Text('선택한 장르의 영화가 없어요.'))
                : _isGrid
                ? GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.58,
                        ),
                    itemCount: movies.length,
                    itemBuilder: (context, index) => MovieCard(
                      movie: movies[index],
                      onTap: () => _openDetail(movies[index]),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: movies.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 24),
                    itemBuilder: (context, index) => MovieListTile(
                      movie: movies[index],
                      onTap: () => _openDetail(movies[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterSummary extends StatelessWidget {
  const _FilterSummary({
    required this.selectedGenres,
    required this.count,
    required this.onClear,
  });

  final Set<String> selectedGenres;
  final int count;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final label = selectedGenres.isEmpty
        ? '전체 영화 $count편'
        : '${selectedGenres.join(', ')} · $count편';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.mutedText),
            ),
          ),
          if (selectedGenres.isNotEmpty)
            TextButton(onPressed: onClear, child: const Text('필터 해제')),
        ],
      ),
    );
  }
}
