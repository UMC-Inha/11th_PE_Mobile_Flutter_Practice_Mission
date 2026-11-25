import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/features/movies/presentation/widgets/favorite_button.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_card.dart';
import 'package:movielog/features/rating/presentation/widgets/movie_rating_dialog.dart';
import 'package:movielog/view_models/favorite_detail_view_model.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/submit_status.dart';
import 'package:movielog/widgets/tmdb_poster_image.dart';
import 'package:provider/provider.dart';

const rateButtonKey = Key('rateButton');
const tmdbIdLabelKey = Key('tmdbIdLabel');
const myRatingLabelKey = Key('myRatingLabel');
const movieTitleKey = Key('movieTitle');

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  @override
  void initState() {
    super.initState();
    // 화면이 처음 만들어질 때 서버의 즐겨찾기 여부를 한 번만 조회한다(build에서 조회하지 않는다).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FavoriteDetailViewModel>().load();
    });
  }

  /// "평점 남기기". 서버에서 확인한 즐겨찾기 상태에 따라 저장 방식이 갈린다.
  ///
  /// - **아직 즐겨찾기하지 않은 영화**(여부를 서버에서 받았고 false): Dialog에 "즐겨찾기에도 추가" 체크박스를
  ///   보여 주고, 평점과 즐겨찾기를 `POST /movie-records` 한 번으로 저장한다.
  /// - 이미 즐겨찾기한 영화, 또는 여부를 아직 모르는 영화: 체크박스 없이 기존 `POST /ratings`로 저장한다.
  Future<void> _rate(
    BuildContext context,
    MovieDetailViewModel viewModel,
  ) async {
    final movie = viewModel.movie!;
    final favorite = context.read<FavoriteDetailViewModel>();
    final integrated = favorite.hasLoadedStatus && !favorite.isFavorite;
    // 다시 눌러도 소용없는 실패(409·404)는 Dialog를 닫고 이 문구를 Snackbar로 안내한다.
    String? closingNotice;

    final saved = await showMovieRatingDialog(
      context,
      movieTitle: movie.title,
      showAddToFavorite: integrated,
      onSubmit: (score, comment, addToFavorites) async {
        // 저장은 Dialog 안에서 일어난다. 실패하면 서버 message를 Dialog에 보여주고 입력은 유지된다.
        if (integrated) {
          final result = await viewModel.saveMovieRecord(
            score: score,
            comment: comment,
            addToFavorites: addToFavorites,
          );
          if (result.isSaved) return;
          final message = result.message ?? '저장에 실패했습니다.';
          if (result.closesDialog) {
            closingNotice = message;
            throw RatingSaveClosedException(message);
          }
          throw RatingSaveException(message);
        }
        await viewModel.createRating(score: score, comment: comment);
        if (viewModel.submitStatus != SubmitStatus.success) {
          throw RatingSaveException(viewModel.submitMessage ?? '저장에 실패했습니다.');
        }
      },
    );
    // await 뒤에는 mounted를 다시 확인한다.
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (integrated) {
      // 저장하든 실패하든, 즐겨찾기 쪽 상태는 화면이 짐작한 값이 아니라 서버 값으로 다시 맞춘다.
      final notice = closingNotice;
      if (notice != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(notice)));
        await favorite.load();
        return;
      }
      if (saved == true) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('평점을 저장했습니다.')));
        await favorite.load();
      }
      return;
    }
    // Dialog가 저장까지 마치고 true를 돌려준 뒤에만 안내한다.
    if (saved != true) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('평점을 등록했습니다. 마이페이지의 "내가 등록한 평점"에서 확인할 수 있습니다.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MovieDetailViewModel>();
    final movie = viewModel.movie;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/movies'),
        ),
      ),
      body: switch (viewModel.status) {
        MovieDetailLoadStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        MovieDetailLoadStatus.error => Center(
          child: Text(viewModel.message ?? '영화를 찾을 수 없어요.'),
        ),
        MovieDetailLoadStatus.success => ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            _PosterHeader(movie: movie!),
            const SizedBox(height: 24),
            _AverageRating(voteAverage: movie.voteAverage),
            const SizedBox(height: 20),
            const Text(
              '줄거리',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (movie.overview.trim().isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    '줄거리 정보가 없어요.',
                    style: TextStyle(color: AppColors.mutedText),
                  ),
                ),
              )
            else
              Text(
                movie.overview,
                style: const TextStyle(color: AppColors.text, height: 1.6),
              ),
            const SizedBox(height: 28),
            if (viewModel.myRating != null) ...[
              Text(
                '내 평점 ${viewModel.myRating!.score}점 · 수정·삭제는 마이페이지에서',
                key: myRatingLabelKey,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
            ],
            FilledButton.icon(
              key: rateButtonKey,
              // 로그인 세션이 정리되는 순간에는 등록할 수 없다(보호 요청은 토큰이 필요하다).
              onPressed: viewModel.canRate
                  ? () => _rate(context, viewModel)
                  : null,
              icon: const Icon(Icons.star_rounded),
              label: const Text('평점 남기기'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'TMDB 영화 ID ${movie.id}',
              key: tmdbIdLabelKey,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
          ],
        ),
      },
    );
  }
}

class _PosterHeader extends StatelessWidget {
  const _PosterHeader({required this.movie});

  final TmdbMovieDto movie;

  @override
  Widget build(BuildContext context) {
    final year = releaseYear(movie);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: TmdbPosterImage(
            posterPath: movie.posterPath,
            height: 360,
            width: double.infinity,
          ),
        ),
        const SizedBox(height: 14),
        // 제목·개봉 연도 오른쪽에 즐겨찾기(북마크) 버튼을 둔다.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      key: movieTitleKey,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    // 개봉일이 없으면 연도를 표시하지 않는다.
                    if (year != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '$year 개봉',
                        style: const TextStyle(color: AppColors.mutedText),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const FavoriteButton(),
          ],
        ),
      ],
    );
  }
}

class _AverageRating extends StatelessWidget {
  const _AverageRating({required this.voteAverage});

  /// TMDB 10점 만점 평균
  final double voteAverage;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF1EDFA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TMDB 평균',
                    style: TextStyle(
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 10점 만점을 별 5개에 맞춰 반으로 나눈다.
                  RatingBarIndicator(
                    rating: voteAverage / 2,
                    itemSize: 22,
                    itemBuilder: (context, _) => const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF5B301),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              voteAverage.toStringAsFixed(1),
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(' / 10', style: TextStyle(color: AppColors.mutedText)),
          ],
        ),
      ),
    );
  }
}
