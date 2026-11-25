import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/tmdb_movie_dto.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../view_models/load_phase.dart';
import '../../view_models/paged_movies_view_model.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/movie_page_footer.dart';
import '../../widgets/movielog_button.dart';
import '../../widgets/tmdb_movie_format.dart';
import '../../widgets/tmdb_poster_image.dart';

/// 영화 검색 화면입니다. 영화 목록과 별도의 [PagedMoviesViewModel]을 사용합니다.
/// 검색어를 제출할 때만 요청하고, 빈 검색어는 서버에 보내지 않습니다.
class MovieSearchScreen extends StatefulWidget {
  const MovieSearchScreen({super.key, required this.onOpenMovie});

  final Future<void> Function(TmdbMovieDto movie) onOpenMovie;

  @override
  State<MovieSearchScreen> createState() => _MovieSearchScreenState();
}

class _MovieSearchScreenState extends State<MovieSearchScreen> {
  final _text = TextEditingController();

  String _submittedQuery = '';
  String? _inputError;

  void _submitSearch(String value) {
    final query = value.trim();

    if (query.isEmpty) {
      setState(() => _inputError = '검색어를 입력해 주세요.');
      return;
    }

    setState(() {
      _inputError = null;
      _submittedQuery = query;
    });

    // 새 검색은 이전 결과를 비우고 page 1부터 시작합니다.
    context.read<PagedMoviesViewModel>().loadInitial(query: query);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화 검색',
        centerTitle: true,
        onBack: () => context.canPop() ? context.pop() : context.go('/movies'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _submitSearch,
                      decoration: InputDecoration(
                        hintText: '영화 제목을 입력하세요',
                        prefixIcon: const Icon(Icons.movie_outlined),
                        errorText: _inputError,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '검색',
                    onPressed: () => _submitSearch(_text.text),
                    icon: const Icon(Icons.search, color: AppColors.violet),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<PagedMoviesViewModel>(
                builder: (context, vm, _) {
                  return switch (vm.phase) {
                    LoadPhase.idle => const Center(
                      child: Text('검색어를 입력해 주세요.'),
                    ),
                    LoadPhase.loading => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    LoadPhase.error => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 40),
                          const SizedBox(height: 12),
                          Text(vm.errorMessage ?? '조회 오류입니다.'),
                          const SizedBox(height: 16),
                          MovieLogButton(
                            label: '다시 시도',
                            onPressed: () =>
                                vm.loadInitial(query: _submittedQuery),
                          ),
                        ],
                      ),
                    ),
                    LoadPhase.empty => Center(
                      child: Text("'$_submittedQuery' 검색 결과가 없습니다."),
                    ),
                    LoadPhase.ready => ListView.separated(
                      itemCount: vm.movies.length + 1,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, index) {
                        if (index == vm.movies.length) {
                          return MoviePageFooter(vm: vm);
                        }
                        final movie = vm.movies[index];
                        return _SearchResultTile(
                          movie: movie,
                          onTap: () => widget.onOpenMovie(movie),
                        );
                      },
                    ),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.movie, required this.onTap});

  final TmdbMovieDto movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final releaseYear = movie.releaseYear;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: TmdbPosterImage(
          posterPath: movie.posterPath,
          width: 48,
          height: 72,
        ),
      ),
      title: Text(
        movie.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: releaseYear == null ? null : Text(releaseYear),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
