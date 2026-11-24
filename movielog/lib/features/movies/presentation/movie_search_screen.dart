import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_list_tile.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_page_footer.dart';
import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:provider/provider.dart';

const movieSearchFieldKey = Key('movieSearchField');
const movieSearchSubmitKey = Key('movieSearchSubmit');
const searchIdleKey = Key('searchIdle');
const searchLoadingKey = Key('searchLoading');
const searchEmptyKey = Key('searchEmpty');
const searchErrorKey = Key('searchError');
const searchRetryKey = Key('searchRetry');
const searchResultsKey = Key('searchResults');

/// 영화 검색(`/movies/search`). 영화 목록과 **별도의** [PagedMoviesViewModel] 인스턴스를 쓴다.
/// 마이페이지의 자식 화면처럼 하단 NavigationBar 없이 AppBar의 BackButton으로 돌아간다.
///
/// 검색어를 **제출할 때만** 요청하고(키보드의 검색 키 또는 검색 아이콘), 빈 검색어는 서버에
/// 보내지 않고 입력 안내만 보여 준다. 화면 상태는 서로 다르다.
/// - idle: 아직 검색하지 않았다
/// - 결과: 카드 목록 + "더 보기"
/// - empty: 검색은 성공했지만 결과가 없다
/// - error: 검색에 실패했다(다시 시도)
class MovieSearchScreen extends StatefulWidget {
  const MovieSearchScreen({super.key});

  @override
  State<MovieSearchScreen> createState() => _MovieSearchScreenState();
}

class _MovieSearchScreenState extends State<MovieSearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    context.read<PagedMoviesViewModel>().search(value);
  }

  void _openMovie(TmdbMovieDto movie) {
    context.push(AppRoutes.movieDetail(movie.id), extra: movie);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.movies),
        ),
        title: const Text(
          '영화 검색',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Consumer<PagedMoviesViewModel>(
        builder: (context, viewModel, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                key: movieSearchFieldKey,
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: _submit,
                onChanged: (value) {
                  if (value.trim().isNotEmpty) viewModel.clearInputHint();
                },
                decoration: InputDecoration(
                  hintText: '영화 제목을 검색해 보세요',
                  errorText: viewModel.inputHint,
                  suffixIcon: IconButton(
                    key: movieSearchSubmitKey,
                    tooltip: '검색',
                    onPressed: () => _submit(_controller.text),
                    icon: const Icon(Icons.search),
                  ),
                ),
              ),
            ),
            Expanded(child: _body(viewModel)),
          ],
        ),
      ),
    );
  }

  Widget _body(PagedMoviesViewModel viewModel) {
    return switch (viewModel.phase) {
      LoadPhase.idle => _message(
        key: searchIdleKey,
        icon: Icons.search,
        title: '찾고 싶은 영화를 검색해 보세요.',
        detail: '검색어를 입력하고 검색 키를 누르면 결과가 보여요.',
      ),
      LoadPhase.loading => const Center(
        child: CircularProgressIndicator(key: searchLoadingKey),
      ),
      LoadPhase.empty => _message(
        key: searchEmptyKey,
        icon: Icons.movie_outlined,
        title: '"${viewModel.query}" 검색 결과가 없어요.',
        detail: '다른 검색어로 다시 검색해 보세요.',
      ),
      LoadPhase.error => _errorBody(viewModel),
      LoadPhase.ready => _results(viewModel),
    };
  }

  Widget _message({
    required Key key,
    required IconData icon,
    required String title,
    required String detail,
  }) {
    return Center(
      key: key,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.mutedText),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBody(PagedMoviesViewModel viewModel) {
    return Center(
      key: searchErrorKey,
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
            Text(
              viewModel.errorMessage ?? '검색 결과를 불러오지 못했어요.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            // 입력창 글자가 아니라 마지막으로 제출한 검색어로 다시 요청한다.
            MovieLogButton(
              key: searchRetryKey,
              label: '다시 시도',
              onPressed: viewModel.reload,
            ),
          ],
        ),
      ),
    );
  }

  Widget _results(PagedMoviesViewModel viewModel) {
    final movies = viewModel.movies;
    return ListView.separated(
      key: searchResultsKey,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: movies.length + 1,
      separatorBuilder: (context, index) => const Divider(height: 24),
      itemBuilder: (context, index) {
        if (index == movies.length) {
          return MoviePageFooter(viewModel: viewModel);
        }
        final movie = movies[index];
        return MovieListTile(movie: movie, onTap: () => _openMovie(movie));
      },
    );
  }
}
