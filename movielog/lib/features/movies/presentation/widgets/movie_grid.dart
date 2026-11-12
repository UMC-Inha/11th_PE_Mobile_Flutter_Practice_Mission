import 'package:flutter/material.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_card.dart';

class MovieGrid extends StatelessWidget {
  const MovieGrid({
    super.key,
    required this.movies,
    required this.onTap,
    this.genreNameOf,
  });

  final List<TmdbMovieDto> movies;
  final ValueChanged<TmdbMovieDto> onTap;
  final String? Function(TmdbMovieDto movie)? genreNameOf;

  @override
  Widget build(BuildContext context) => GridView.builder(
    // 목록이 짧아도 당겨서 새로고침이 되도록 항상 스크롤 가능하게 둔다.
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
  );
}
