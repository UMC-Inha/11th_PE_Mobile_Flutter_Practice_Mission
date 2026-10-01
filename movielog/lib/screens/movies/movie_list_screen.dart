import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/movie.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/movie_card.dart';
import '../../widgets/search_action_button.dart';
import 'widgets/genre_chip_bar.dart';

class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key, this.selectedGenre = allGenreLabel});

  /// Router가 Query Parameter(`/movies?genre=SF`)에서 읽어 전달한 장르입니다.
  final String selectedGenre;

  void _selectGenre(BuildContext context, String genre) {
    // 선택한 장르를 Query Parameter로 URL에 표현합니다. '전체'는 조건 없이 /movies로 이동합니다.
    final location = Uri(
      path: '/movies',
      queryParameters: genre == allGenreLabel ? null : {'genre': genre},
    ).toString();

    context.go(location);
  }

  @override
  Widget build(BuildContext context) {
    final filteredMovies = moviesByGenre(selectedGenre);

    return Scaffold(
      appBar: const CommonAppBar(
        title: '영화',
        actions: [SearchActionButton(color: AppColors.darkGray)],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            GenreChipBar(
              genres: movieGenres,
              selectedGenre: selectedGenre,
              onSelected: (genre) => _selectGenre(context, genre),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: filteredMovies.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 24,
                  childAspectRatio: 0.56,
                ),
                itemBuilder: (context, index) {
                  return MovieCard(movie: filteredMovies[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
