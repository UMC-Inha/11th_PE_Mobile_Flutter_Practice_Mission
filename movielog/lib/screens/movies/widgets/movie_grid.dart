import 'package:flutter/material.dart';

import '../../../data/models/tmdb_movie_dto.dart';
import '../../../widgets/tmdb_movie_card.dart';

/// 영화 목록 Ready 상태에서 표시하는 2열 Grid입니다.
/// [footer]는 카드 목록 아래에 붙습니다. (더 보기·재시도·끝 상태)
class MovieGrid extends StatelessWidget {
  const MovieGrid({super.key, required this.movies, this.footer});

  final List<TmdbMovieDto> movies;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverGrid.builder(
            itemCount: movies.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 24,
              childAspectRatio: 0.56,
            ),
            itemBuilder: (context, index) {
              return TmdbMovieCard(movie: movies[index]);
            },
          ),
        ),
        if (footer != null) SliverToBoxAdapter(child: footer),
      ],
    );
  }
}
