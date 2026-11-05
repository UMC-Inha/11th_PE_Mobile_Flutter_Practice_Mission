import 'package:shared_preferences/shared_preferences.dart';

enum MovieSort { original, title, rating }

class MovieListSettings {
  const MovieListSettings({
    this.genreIds = const [],
    this.sort = MovieSort.original,
  });

  /// 5주차부터 장르 이름 대신 TMDB 장르 ID를 저장한다. 비어 있으면 "전체".
  final List<int> genreIds;
  final MovieSort sort;
}

abstract interface class MoviePreferences {
  Future<MovieListSettings> read();
  Future<void> save(MovieListSettings settings);
}

class GenrePreference implements MoviePreferences {
  GenrePreference({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  /// 4주차 키(`selected_genre`, 장르 이름)는 TMDB ID와 섞이지 않게 새 키로 바꿨다.
  static const selectedGenreKey = 'selected_genre_ids';
  static const sortKey = 'movie_sort';
  final SharedPreferencesAsync _preferences;

  @override
  Future<MovieListSettings> read() async {
    final values = await Future.wait<String?>([
      _preferences.getString(selectedGenreKey),
      _preferences.getString(sortKey),
    ]);
    return MovieListSettings(
      genreIds: parseGenreIds(values[0]),
      sort: MovieSort.values.firstWhere(
        (sort) => sort.name == values[1],
        orElse: () => MovieSort.original,
      ),
    );
  }

  @override
  Future<void> save(MovieListSettings settings) async {
    // 토큰·비밀번호·영화 객체는 저장하지 않는다.
    await _preferences.setString(selectedGenreKey, settings.genreIds.join(','));
    await _preferences.setString(sortKey, settings.sort.name);
  }
}

/// "28,12" → [28, 12]. 숫자가 아닌 조각과 중복은 버린다.
List<int> parseGenreIds(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  final ids = <int>{};
  for (final part in raw.split(RegExp(r'[,|]'))) {
    final id = int.tryParse(part.trim());
    if (id != null && id > 0) ids.add(id);
  }
  return ids.toList();
}
