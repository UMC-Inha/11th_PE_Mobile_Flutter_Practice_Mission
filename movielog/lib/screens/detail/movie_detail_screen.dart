import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/tmdb_movie_dto.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common_app_bar.dart';
import 'widgets/detail_action_bar.dart';
import 'widgets/movie_detail_header.dart';
import 'widgets/movie_synopsis.dart';
import 'widgets/rating_dialog.dart';
import 'widgets/share_bottom_sheet.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movie});

  /// Router가 extra로 전달한 TMDB 영화입니다. Path Parameter의 id와 맞지 않거나 없으면 null입니다.
  final TmdbMovieDto? movie;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  // 즐겨찾기와 내 평점은 API 없이 화면 내부 상태로만 관리합니다.
  bool _isFavorite = false;
  double? _myRating;

  static final _titleStyle = AppTextStyles.titleLarge.copyWith(
    color: AppColors.violet,
    fontSize: 22,
  );

  void _goBack() {
    // URL로 바로 진입해 이전 화면이 없으면 홈으로 이동합니다.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _toggleFavorite(TmdbMovieDto movie) {
    setState(() => _isFavorite = !_isFavorite);
    _showSnackBar(
      _isFavorite
          ? '\'${movie.title}\'을(를) 즐겨찾기에 추가했어요.'
          : '\'${movie.title}\'을(를) 즐겨찾기에서 삭제했어요.',
    );
  }

  Future<void> _openRatingDialog(TmdbMovieDto movie) async {
    final rating = await showDialog<double>(
      context: context,
      // TMDB id를 평점 Dialog에 전달합니다. (배열 index가 아닌 영화 식별값)
      builder: (dialogContext) => RatingDialog(
        movieId: movie.id,
        initialRating: _myRating ?? 0,
      ),
    );
    if (!mounted || rating == null) return;

    setState(() => _myRating = rating);
    _showSnackBar('평점 $rating점을 남겼어요.');
  }

  Future<void> _openShareSheet() async {
    final option = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => const ShareBottomSheet(),
    );
    // BottomSheet가 닫힌 뒤 Snackbar를 표시해야 Sheet 뒤에 가려지지 않습니다.
    if (!mounted || option == null) return;
    _showSnackBar('$option (Mock)');
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;

    if (movie == null) {
      return Scaffold(
        appBar: CommonAppBar(
          title: 'Cinema Archive',
          centerTitle: true,
          titleStyle: _titleStyle,
          onBack: _goBack,
        ),
        body: const Center(
          child: Text('영화를 찾을 수 없어요.', style: AppTextStyles.bodySmall),
        ),
      );
    }

    return Scaffold(
      appBar: CommonAppBar(
        title: 'Cinema Archive',
        centerTitle: true,
        titleStyle: _titleStyle,
        onBack: _goBack,
        actions: [
          IconButton(
            tooltip: '공유하기',
            onPressed: _openShareSheet,
            icon: const Icon(Icons.share, color: AppColors.darkGray),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MovieDetailHeader(movie: movie, myRating: _myRating),
                    const Divider(height: 1, color: AppColors.divider),
                    MovieSynopsis(synopsis: movie.overview),
                  ],
                ),
              ),
            ),
            DetailActionBar(
              isFavorite: _isFavorite,
              onFavoritePressed: () => _toggleFavorite(movie),
              onRatePressed: () => _openRatingDialog(movie),
            ),
          ],
        ),
      ),
    );
  }
}
