import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/data/models/rating_with_movie.dart';
import 'package:movielog/features/my_page/presentation/widgets/delete_rating_dialogs.dart';
import 'package:movielog/features/rating/presentation/widgets/movie_rating_dialog.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/widgets/loading_overlay.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:movielog/widgets/tmdb_poster_image.dart';
import 'package:provider/provider.dart';

const myRatingsRetryKey = Key('myRatingsRetry');
const myRatingsLoadingKey = Key('myRatingsLoading');
const myRatingsEmptyKey = Key('myRatingsEmpty');
const myRatingsErrorKey = Key('myRatingsError');
const myRatingsNoticeKey = Key('myRatingsNotice');
const myRatingsRefreshWarningKey = Key('myRatingsRefreshWarning');
const myRatingsPopScopeKey = Key('myRatingsPopScope');
const myRatingsEditToggleKey = Key('myRatingsEditToggle');
const myRatingsDeletingOverlayKey = Key('myRatingsDeletingOverlay');
const deleteSelectedButtonKey = Key('deleteSelectedButton');

/// 마이페이지 → "내가 등록한 평점". 마이페이지 위에 열리는 자식 화면이라
/// 하단 NavigationBar 없이 AppBar의 BackButton으로 돌아간다.
///
/// 조회 대상은 회원가입 결과로 보관한 학습용 memberId의 평점이다(로그인 인증이 아니다).
/// 카드마다 수정·삭제 버튼이 있고, 상단 "편집"으로 체크박스 다중 선택 삭제 모드에 들어간다.
class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  Future<void> _onEdit(BuildContext context, RatingWithMovie entry) async {
    final viewModel = context.read<MyRatingsViewModel>();
    final rating = entry.rating;
    final saved = await showMovieRatingDialog(
      context,
      title: '평점 수정하기',
      movieTitle: entry.movie?.title ?? '영화 ${rating.movieId}',
      // 기존 값을 Dialog 초기값으로 넣는다. comment가 null이면 코멘트 칸은 빈 채로 열린다.
      initialScore: rating.score,
      initialComment: rating.comment,
      onSubmit: (score, comment) => viewModel.updateRating(
        ratingId: rating.ratingId,
        score: score,
        comment: comment,
      ),
    );
    if (!context.mounted || saved != true) return;
    _showSnackBar(context, '평점을 수정했어요.');
  }

  Future<void> _onDelete(BuildContext context, RatingWithMovie entry) async {
    final viewModel = context.read<MyRatingsViewModel>();
    final deleted = await showDeleteRatingDialog(
      context,
      onConfirm: () => viewModel.deleteRating(entry.rating.ratingId),
    );
    if (!context.mounted || deleted != true) return;
    _showSnackBar(context, '평점을 삭제했어요.');
  }

  Future<void> _onDeleteSelected(BuildContext context) async {
    final viewModel = context.read<MyRatingsViewModel>();
    final confirmed = await showDeleteSelectedConfirmDialog(
      context,
      count: viewModel.selectedRatingIds.length,
    );
    // 확인 Dialog는 여기서 이미 닫혔다. 삭제 요청은 이 화면의 ViewModel이 이어받는다.
    if (confirmed != true || !context.mounted) return;
    final result = await viewModel.deleteSelectedRatings();
    if (!context.mounted) return;
    if (result.failed > 0) {
      _showSnackBar(
        context,
        '${result.failed}개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.',
      );
    } else if (result.deleted > 0) {
      _showSnackBar(context, '${result.deleted}개의 평점을 삭제했어요.');
    }
  }

  void _showSnackBar(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MyRatingsViewModel>();
    // 다중 삭제가 끝나기 전에 화면을 벗어나면 이미 나간 요청의 결과를 반영하지 못한다.
    return PopScope(
      key: myRatingsPopScopeKey,
      canPop: !viewModel.isDeletingSelected,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          leading: const BackButton(),
          title: const Text(
            '내가 등록한 평점',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            // 평점이 있을 때만 편집할 수 있다.
            if (viewModel.status == MyRatingsLoadStatus.success)
              TextButton(
                key: myRatingsEditToggleKey,
                onPressed: viewModel.isDeletingSelected
                    ? null
                    : viewModel.isEditing
                    ? viewModel.cancelEditing
                    : viewModel.startEditing,
                child: Text(viewModel.isEditing ? '취소' : '편집'),
              ),
          ],
        ),
        // 편집 중에만 "선택한 N개 삭제" 바가 하단에 붙는다(마이페이지의 NavigationBar와는 별개).
        bottomNavigationBar: viewModel.isEditing
            ? _DeleteSelectedBar(
                count: viewModel.selectedRatingIds.length,
                // 오버레이는 본문만 덮으므로 삭제 중에는 이 바도 스스로 꺼 둔다.
                // 안 그러면 삭제가 도는 중에 두 번째 확인 Dialog가 열린다.
                onPressed:
                    viewModel.selectedRatingIds.isEmpty ||
                        viewModel.isDeletingSelected
                    ? null
                    : () => _onDeleteSelected(context),
              )
            : null,
        body: LoadingOverlay(
          key: myRatingsDeletingOverlayKey,
          isLoading: viewModel.isDeletingSelected,
          child: RefreshIndicator(
            onRefresh: () => viewModel.load(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _SampleNotice(memberId: viewModel.memberId),
                const SizedBox(height: 16),
                _StatsRow(viewModel: viewModel),
                const SizedBox(height: 20),
                ..._body(context, viewModel),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, MyRatingsViewModel viewModel) {
    switch (viewModel.status) {
      case MyRatingsLoadStatus.idle:
      case MyRatingsLoadStatus.loading:
        return const [
          Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: CircularProgressIndicator(key: myRatingsLoadingKey),
            ),
          ),
        ];
      case MyRatingsLoadStatus.error:
        return [
          Column(
            key: myRatingsErrorKey,
            children: [
              const SizedBox(height: 16),
              const Icon(Icons.cloud_off_outlined, color: AppColors.mutedText),
              const SizedBox(height: 8),
              // 저장은 끝났는데 목록 조회만 실패한 경우, 그 사실을 먼저 알려
              // 같은 쓰기를 다시 보내는 일(409 등)을 막는다. 재시도는 GET만 다시 보낸다.
              Text(
                viewModel.refreshWarning ??
                    viewModel.message ??
                    '평점을 불러오지 못했어요.',
                key: viewModel.refreshWarning == null
                    ? null
                    : myRatingsRefreshWarningKey,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.mutedText),
              ),
              const SizedBox(height: 12),
              MovieLogButton(
                key: myRatingsRetryKey,
                label: '다시 시도',
                onPressed: () => viewModel.load(),
              ),
            ],
          ),
        ];
      case MyRatingsLoadStatus.empty:
        return const [
          Padding(
            key: myRatingsEmptyKey,
            padding: EdgeInsets.all(32),
            child: Center(child: Text('아직 남긴 평점이 없어요.')),
          ),
        ];
      case MyRatingsLoadStatus.success:
        return [
          if (viewModel.message != null)
            Padding(
              key: myRatingsNoticeKey,
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                viewModel.message!,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 13,
                ),
              ),
            ),
          for (final entry in viewModel.ratings)
            _RatingTile(
              entry: entry,
              isEditing: viewModel.isEditing,
              isSelected: viewModel.selectedRatingIds.contains(
                entry.rating.ratingId,
              ),
              onTap: viewModel.isEditing
                  // 편집 중에는 카드를 눌러도 선택만 바뀐다. 상세로 이동하지 않는다.
                  ? () => viewModel.toggleSelection(entry.rating.ratingId)
                  : () => context.push(
                      AppRoutes.movieDetail(entry.rating.movieId),
                      extra: entry.movie,
                    ),
              onEdit: () => _onEdit(context, entry),
              onDelete: () => _onDelete(context, entry),
            ),
        ];
    }
  }
}

/// 로그인(인증)이 아직 없어서, 회원가입으로 받은 memberId로 조회한 평점임을 알린다.
class _SampleNotice extends StatelessWidget {
  const _SampleNotice({required this.memberId});

  final int memberId;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF1EDFA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '로그인 전이라 방금 가입한 학습용 회원 #$memberId의 평점을 보여줘요.',
                style: const TextStyle(color: AppColors.text, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.viewModel});

  final MyRatingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final loaded =
        viewModel.status == MyRatingsLoadStatus.success ||
        viewModel.status == MyRatingsLoadStatus.empty;
    // 조회에 실패한 상태에서는 남아 있는 이전 목록의 평균을 보여 주지 않는다("남긴 평점"이 -인데
    // 평균만 낡은 값을 보여 주면 서로 어긋난다).
    final average = loaded ? viewModel.averageScore : null;
    return Row(
      children: [
        _StatItem(
          label: '남긴 평점',
          value: loaded ? '${viewModel.ratings.length}' : '-',
        ),
        const SizedBox(width: 12),
        _StatItem(
          label: '평균 점수',
          value: average == null ? '-' : average.toStringAsFixed(1),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF1EDFA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: AppColors.mutedText)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingTile extends StatelessWidget {
  const _RatingTile({
    required this.entry,
    required this.isEditing,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final RatingWithMovie entry;

  /// true면 수정·삭제 버튼 대신 체크박스를 보여준다.
  final bool isEditing;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final rating = entry.rating;
    final movie = entry.movie;
    final comment = rating.comment?.trim();
    final date = rating.createdAt.toLocal();
    final day =
        '${date.year}.${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
    return InkWell(
      key: Key('ratingTile-${rating.ratingId}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              // movie가 null이면 TmdbPosterImage가 "포스터 없음" placeholder를 그린다.
              child: TmdbPosterImage(
                posterPath: movie?.posterPath,
                width: 60,
                height: 88,
                size: 'w185',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie?.title ?? '영화 정보 없음',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${'★' * rating.score}${'☆' * (5 - rating.score)}  ${rating.score}점',
                    style: const TextStyle(color: Color(0xFFE0A100)),
                  ),
                  // 후기가 없으면(null) 자리를 비우지 않고 아예 그리지 않는다.
                  if (comment != null && comment.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      comment,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.text),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'movieId ${rating.movieId} · $day',
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isEditing)
              Checkbox(
                key: Key('ratingCheckbox-${rating.ratingId}'),
                value: isSelected,
                onChanged: (_) => onTap(),
              )
            else ...[
              _TileAction(
                key: Key('ratingEditButton-${rating.ratingId}'),
                tooltip: '평점 수정',
                icon: Icons.edit_outlined,
                onPressed: onEdit,
              ),
              _TileAction(
                key: Key('ratingDeleteButton-${rating.ratingId}'),
                tooltip: '평점 삭제',
                icon: Icons.delete_outline,
                onPressed: onDelete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TileAction extends StatelessWidget {
  const _TileAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: AppColors.mutedText),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
    );
  }
}

/// 편집 모드 하단 바. 선택이 1개 이상일 때만 활성화된다.
class _DeleteSelectedBar extends StatelessWidget {
  const _DeleteSelectedBar({required this.count, required this.onPressed});

  final int count;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: MovieLogButton(
          key: deleteSelectedButtonKey,
          label: '선택한 $count개 삭제',
          height: 52,
          width: double.infinity,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
