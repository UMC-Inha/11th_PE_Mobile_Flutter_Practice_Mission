import 'package:movielog/core/storage/genre_preference.dart';

class MemoryMoviePreferences implements MoviePreferences {
  MemoryMoviePreferences([this.settings = const MovieListSettings()]);
  MovieListSettings settings;
  int writes = 0;
  @override
  Future<MovieListSettings> read() async => settings;
  @override
  Future<void> save(MovieListSettings value) async {
    settings = value;
    writes++;
  }
}
