import 'package:flutter/material.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_card.dart';

class MovieGrid extends StatelessWidget {
  const MovieGrid({
    super.key,
    required this.movies,
    required this.onTap,
    this.genreNameOf,
    this.controller,
    this.footer,
  });

  final List<TmdbMovieDto> movies;
  final ValueChanged<TmdbMovieDto> onTap;
  final String? Function(TmdbMovieDto movie)? genreNameOf;

  /// 무한 스크롤처럼 화면이 스크롤 위치를 알아야 할 때 넘긴다.
  final ScrollController? controller;

  /// 격자 아래에 한 줄을 통째로 쓰는 footer("더 보기"·로딩·오류·끝).
  final Widget? footer;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    controller: controller,
    // 목록이 짧아도 당겨서 새로고침이 되도록 항상 스크롤 가능하게 둔다.
    physics: const AlwaysScrollableScrollPhysics(),
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 20,
            crossAxisSpacing: 16,
            childAspectRatio: 0.56,
          ),
          itemCount: movies.length,
          itemBuilder: (context, index) => MovieCard(
            movie: movies[index],
            genreName: genreNameOf?.call(movies[index]),
            onTap: () => onTap(movies[index]),
          ),
        ),
      ),
      if (footer != null) SliverToBoxAdapter(child: footer),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ],
  );
}
