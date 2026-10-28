import 'package:flutter/material.dart';

import '../../../data/models/tmdb_movie_dto.dart';
import '../../../widgets/tmdb_movie_card.dart';

/// 영화 목록 Success 상태에서 표시하는 2열 Grid입니다.
class MovieGrid extends StatelessWidget {
  const MovieGrid({super.key, required this.movies});

  final List<TmdbMovieDto> movies;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
    );
  }
}
