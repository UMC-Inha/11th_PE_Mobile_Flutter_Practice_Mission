import 'package:shared_preferences/shared_preferences.dart';

import '../models/movie.dart';

/// 마지막으로 선택한 장르를 로컬에 저장하고 복원합니다.
class GenrePreference {
  GenrePreference({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _selectedGenreKey = 'selected_genre';

  final SharedPreferencesAsync _preferences;

  Future<String> read() async {
    return await _preferences.getString(_selectedGenreKey) ?? allGenreLabel;
  }

  Future<void> save(String genre) async {
    await _preferences.setString(_selectedGenreKey, genre);
  }

  Future<void> clear() async {
    await _preferences.remove(_selectedGenreKey);
  }
}
