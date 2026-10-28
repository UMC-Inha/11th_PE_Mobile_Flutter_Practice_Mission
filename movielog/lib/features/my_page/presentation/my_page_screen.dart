import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/data/models/movielog_dtos.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/widgets/tmdb_poster_image.dart';
import 'package:provider/provider.dart';

const myRatingsRetryKey = Key('myRatingsRetry');

/// 마이페이지. "내가 남긴 평점"은 자체 백엔드 GET /members/{memberId}/ratings 결과다.
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          '마이페이지',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Consumer<MyRatingsViewModel>(
        builder: (context, viewModel, _) => RefreshIndicator(
          onRefresh: viewModel.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const _ProfileHeader(),
              const SizedBox(height: 24),
              _StatsRow(viewModel: viewModel),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '내가 남긴 평점',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '회원 #${viewModel.memberId}',
                    style: const TextStyle(color: AppColors.mutedText),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                '로그인(7주차) 전이라 시드 회원 1번의 평점을 불러와요.',
                style: TextStyle(color: AppColors.mutedText, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ..._ratings(context, viewModel),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _ratings(BuildContext context, MyRatingsViewModel viewModel) {
    switch (viewModel.status) {
      case MyRatingsLoadStatus.idle:
      case MyRatingsLoadStatus.loading:
        return const [
          Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      case MyRatingsLoadStatus.error:
        return [
          const SizedBox(height: 16),
          const Icon(Icons.cloud_off_outlined, color: AppColors.mutedText),
          const SizedBox(height: 8),
          Text(
            viewModel.message ?? '내 평점을 불러오지 못했어요.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedText),
          ),
          Center(
            child: TextButton(
              key: myRatingsRetryKey,
              onPressed: viewModel.load,
              child: const Text('다시 시도'),
            ),
          ),
        ];
      case MyRatingsLoadStatus.empty:
        return const [
          Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('아직 남긴 평점이 없어요.')),
          ),
        ];
      case MyRatingsLoadStatus.success:
        return [
          for (final rating in viewModel.ratings)
            _RatingTile(
              rating: rating,
              movie: viewModel.moviesById[rating.movieId],
              onTap: () {
                final movie = viewModel.moviesById[rating.movieId];
                context.push(
                  AppRoutes.movieDetail(rating.movieId),
                  extra: movie,
                );
              },
            ),
        ];
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundImage: AssetImage(
            'assets/images/profile/profile_movielog.jpg',
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '케빈',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '별빛 아래에서 영화를 기록하는 중',
                style: TextStyle(color: AppColors.mutedText),
              ),
            ],
          ),
        ),
      ],
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
  const _RatingTile({
    required this.rating,
    required this.movie,
    required this.onTap,
  });

  final MemberRatingDto rating;
  final TmdbMovieDto? movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                    movie?.title ?? 'TMDB 영화 #${rating.movieId}',
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
                  if (rating.comment != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      rating.comment!,
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
