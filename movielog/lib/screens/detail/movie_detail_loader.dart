import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/tmdb_movie_dto.dart';
import '../../data/services/rating_api_service.dart';
import '../../data/services/tmdb_movie_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../view_models/learning_member_session.dart';
import '../../view_models/movie_detail_view_model.dart';
import '../../widgets/common_app_bar.dart';
import 'movie_detail_screen.dart';

/// 영화 상세 화면의 시작점입니다.
/// 목록·홈 카드가 extra로 넘긴 영화가 있으면 그대로 쓰고,
/// URL 직접 진입·Deep Link처럼 extra가 없으면 TMDB `GET /movie/{movie_id}`로 다시 조회합니다.
class MovieDetailLoader extends StatefulWidget {
  const MovieDetailLoader({
    super.key,
    required this.movieId,
    this.initialMovie,
  });

  final int movieId;
  final TmdbMovieDto? initialMovie;

  @override
  State<MovieDetailLoader> createState() => _MovieDetailLoaderState();
}

class _MovieDetailLoaderState extends State<MovieDetailLoader> {
  // build마다 새 Future를 만들지 않도록 한 번만 만듭니다.
  late final Future<TmdbMovieDto> _movieFuture;

  @override
  void initState() {
    super.initState();
    final initialMovie = widget.initialMovie;
    _movieFuture = initialMovie != null
        ? Future.value(initialMovie)
        : context.read<TmdbMovieService>().fetchMovieDetail(widget.movieId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TmdbMovieDto>(
      future: _movieFuture,
      // extra가 있으면 첫 프레임부터 영화를 그립니다.
      initialData: widget.initialMovie,
      builder: (context, snapshot) {
        final movie = snapshot.data;
        if (movie != null) {
          return ChangeNotifierProvider<MovieDetailViewModel>(
            create: (context) => MovieDetailViewModel(
              context.read<RatingApiService>(),
              context.read<LearningMemberSession>().memberId,
              movie,
            ),
            child: const MovieDetailScreen(),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const _DetailMessage(child: CircularProgressIndicator());
        }
        return const _DetailMessage(
          child: Text('영화를 불러오지 못했습니다.', style: AppTextStyles.bodySmall),
        );
      },
    );
  }
}

/// 상세 화면과 같은 AppBar 아래에 로딩·오류를 보여줍니다.
class _DetailMessage extends StatelessWidget {
  const _DetailMessage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: 'Cinema Archive',
        centerTitle: true,
        titleStyle: AppTextStyles.titleLarge.copyWith(
          color: AppColors.violet,
          fontSize: 22,
        ),
        onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      ),
      body: Center(child: child),
    );
  }
}
