import 'dart:async';

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
/// 검색은 두 가지로 시작한다. 키보드의 검색 키·검색 아이콘으로 **제출**하면 바로 요청하고,
/// 입력만 해도 **마지막 입력 500ms 뒤에** 한 번 요청한다(debounce). 빈 검색어는 어느 쪽이든
/// 서버에 보내지 않는다(제출이면 입력 안내를 보여 준다). 화면 상태는 서로 다르다.
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
  /// 마지막 입력 뒤 이 시간이 지나야 자동으로 검색한다.
  static const debounceDelay = Duration(milliseconds: 500);

  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    // 화면이 사라진 뒤에는 대기 중인 검색이 실행되지 않게 타이머를 취소한다.
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// 제출(검색 키·검색 아이콘): 기다리지 않고 바로 검색한다. 대기 중이던 자동 검색은 취소해
  /// 같은 검색어가 두 번 나가지 않게 한다.
  void _submit(String value) {
    _debounce?.cancel();
    context.read<PagedMoviesViewModel>().search(value);
  }

  /// 입력할 때마다 이전 타이머를 취소하고 새로 시작한다. 타이머가 실행되는 시점에야 검색한다.
  void _onChanged(String value, PagedMoviesViewModel viewModel) {
    if (value.trim().isNotEmpty) viewModel.clearInputHint();
    _debounce?.cancel();
    _debounce = Timer(debounceDelay, () {
      if (!mounted) return;
      final query = value.trim();
      if (query.isEmpty) return; // 빈 검색어는 요청하지 않는다
      context.read<PagedMoviesViewModel>().search(query);
    });
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
                onChanged: (value) => _onChanged(value, viewModel),
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
        detail: '입력을 멈추면 잠시 뒤 결과가 보이고, 검색 키를 누르면 바로 검색해요.',
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
