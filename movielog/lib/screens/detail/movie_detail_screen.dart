import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/services/rating_api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../view_models/favorite_detail_view_model.dart';
import '../../view_models/movie_detail_view_model.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/favorite_button.dart';
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
  /// Route에서 즐겨찾기 ViewModel을 제공했을 때만 북마크 버튼을 보여줍니다.
  /// (상세 화면만 단독으로 띄우는 위젯 테스트에서는 없을 수 있습니다.)
  FavoriteDetailViewModel? get _favoriteViewModel =>
      Provider.of<FavoriteDetailViewModel?>(context, listen: false);

  @override
  void initState() {
    super.initState();
    // build()에서는 조회하지 않고, 화면이 처음 만들어질 때 서버의 즐겨찾기 여부를 한 번 조회합니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _favoriteViewModel?.load();
    });
  }

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
                      // 제목·정보 텍스트 오른쪽에 북마크 버튼을 둡니다.
                      trailing: _favoriteViewModel == null
                          ? null
                          : const FavoriteButton(),
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    MovieSynopsis(synopsis: movie.overview),
                  ],
                ),
              ),
            ),
            DetailActionBar(onRatePressed: _openRatingDialog),
          ],
        ),
      ),
    );
  }
}
