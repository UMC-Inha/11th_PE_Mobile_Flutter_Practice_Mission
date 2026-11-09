import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/tmdb_movie_dto.dart';
import '../../data/services/rating_api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../view_models/movie_detail_view_model.dart';
import '../../widgets/common_app_bar.dart';
import 'widgets/detail_action_bar.dart';
import 'widgets/movie_detail_header.dart';
import 'widgets/movie_synopsis.dart';
import 'widgets/rating_dialog.dart';
import 'widgets/share_bottom_sheet.dart';

/// 영화 상세 화면입니다. 영화와 평점 등록 상태는 [MovieDetailViewModel]에서 읽습니다.
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  // 즐겨찾기는 API 없이 화면 내부 상태로만 관리합니다.
  bool _isFavorite = false;

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
          duration: const Duration(seconds: 3),
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

  Future<void> _openRatingDialog() async {
    final viewModel = context.read<MovieDetailViewModel>();
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막습니다.
      builder: (_) => RatingDialog(
        onSubmit: (score, comment) async {
          await viewModel.createRating(score: score, comment: comment);
          if (viewModel.submitStatus != SubmitStatus.success) {
            throw RatingWriteException(
              viewModel.submitMessage ?? '저장에 실패했습니다.',
            );
          }
        },
      ),
    );

    // 저장 요청과 Snackbar 표시는 서로 다른 비동기 경계라 mounted를 다시 확인합니다.
    if (!mounted) return;
    if (saved == true) {
      _showSnackBar('평점을 등록했습니다. 마이페이지의 "내가 등록한 평점"에서 확인할 수 있습니다.');
    } else if (viewModel.submitStatus == SubmitStatus.error) {
      // 실패 후 Dialog를 닫았다면 등록되지 않았다는 사실을 한 번 더 알려줍니다.
      _showSnackBar('평점이 등록되지 않았어요. ${viewModel.submitMessage ?? ''}'.trim());
    }
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
    final viewModel = context.watch<MovieDetailViewModel>();
    final movie = viewModel.movie;

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
                    MovieDetailHeader(
                      movie: movie,
                      myRating: viewModel.myScore,
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    MovieSynopsis(synopsis: movie.overview),
                  ],
                ),
              ),
            ),
            DetailActionBar(
              isFavorite: _isFavorite,
              onFavoritePressed: () => _toggleFavorite(movie),
              // 학습용 회원가입 전에는 평점을 남길 수 없습니다.
              onRatePressed: viewModel.canRate ? _openRatingDialog : null,
              notice: viewModel.canRate ? null : '학습용 회원가입을 완료하면 평점을 남길 수 있어요.',
            ),
          ],
        ),
      ),
    );
  }
}
