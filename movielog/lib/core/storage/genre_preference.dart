import 'package:movielog/core/data/mock_movies.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MovieSort { original, title, rating }

class MovieListSettings {
  const MovieListSettings({
    this.genres = const {},
    this.sort = MovieSort.original,
  });
  final Set<String> genres;
  final MovieSort sort;
}

abstract interface class MoviePreferences {
  Future<MovieListSettings> read();
  Future<void> save(MovieListSettings settings);
}

class GenrePreference implements MoviePreferences {
  GenrePreference({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  static const selectedGenreKey = 'selected_genre';
  static const sortKey = 'movie_sort';
  final SharedPreferencesAsync _preferences;

  @override
  Future<MovieListSettings> read() async {
    final values = await Future.wait<String?>([
      _preferences.getString(selectedGenreKey),
      _preferences.getString(sortKey),
    ]);
    final genres = (values[0] ?? '')
        .split(',')
        .where(movieGenres.contains)
        .toSet();
    final sort = MovieSort.values.firstWhere(
      (sort) => sort.name == values[1],
      orElse: () => MovieSort.original,
    );
    return MovieListSettings(genres: genres, sort: sort);
  }

  @override
  Future<void> save(MovieListSettings settings) async {
    // 토큰·비밀번호·영화 객체는 저장하지 않는다.
    await _preferences.setString(selectedGenreKey, settings.genres.join(','));
    await _preferences.setString(sortKey, settings.sort.name);
  }
}
