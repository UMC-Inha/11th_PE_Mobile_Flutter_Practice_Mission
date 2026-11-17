import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/data/models/rating_with_movie.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:movielog/widgets/tmdb_poster_image.dart';
import 'package:provider/provider.dart';

const myRatingsRetryKey = Key('myRatingsRetry');
const myRatingsLoadingKey = Key('myRatingsLoading');
const myRatingsEmptyKey = Key('myRatingsEmpty');
const myRatingsErrorKey = Key('myRatingsError');
const myRatingsNoticeKey = Key('myRatingsNotice');

/// 마이페이지 → "내가 등록한 평점". 마이페이지 위에 열리는 자식 화면이라
/// 하단 NavigationBar 없이 AppBar의 BackButton으로 돌아간다.
///
/// 조회 대상은 로그인한 본인이 아니라 학습용 memberId 1의 공개 데이터다.
class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: const BackButton(),
        title: const Text(
          '내가 등록한 평점',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      // bottomNavigationBar를 전달하지 않는다.
      body: Consumer<MyRatingsViewModel>(
        builder: (context, viewModel, _) => RefreshIndicator(
          onRefresh: viewModel.load,
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
              Text(
                viewModel.message ?? '평점을 불러오지 못했어요.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.mutedText),
              ),
              const SizedBox(height: 12),
              MovieLogButton(
                key: myRatingsRetryKey,
                label: '다시 시도',
                onPressed: viewModel.load,
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
              onTap: () => context.push(
                AppRoutes.movieDetail(entry.rating.movieId),
                extra: entry.movie,
              ),
            ),
        ];
    }
  }
}

/// 로그인 기능이 생기기 전이라 "내 평점"이 아니라 샘플 회원의 공개 조회임을 알린다.
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
                '로그인(7주차) 전이라 학습용 회원 #$memberId의 공개 평점을 보여줘요.',
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
    final average = viewModel.averageScore;
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
  const _RatingTile({required this.entry, required this.onTap});

  final RatingWithMovie entry;
  final VoidCallback onTap;

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
            const Icon(Icons.chevron_right, color: AppColors.mutedText),
          ],
        ),
      ),
    );
  }
}
