import 'package:flutter/material.dart';
import 'package:movielog/core/data/mock_movies.dart';
import 'package:movielog/features/movies/presentation/widgets/movie_card.dart';

class MovieGrid extends StatelessWidget {
  const MovieGrid({super.key, required this.movies, required this.onTap});
  final List<Movie> movies;
  final ValueChanged<Movie> onTap;
  @override
  Widget build(BuildContext context) => GridView.builder(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 20,
      crossAxisSpacing: 16,
      childAspectRatio: 0.58,
    ),
    itemCount: movies.length,
    itemBuilder: (context, index) =>
        MovieCard(movie: movies[index], onTap: () => onTap(movies[index])),
  );
}
