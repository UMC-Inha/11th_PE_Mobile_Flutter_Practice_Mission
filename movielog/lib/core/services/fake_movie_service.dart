import 'package:movielog/core/data/mock_movies.dart';

enum MovieLoadMode { success, empty, failure, timeout }

class MovieLoadException implements Exception {
  const MovieLoadException();
}

abstract interface class MovieService {
  Future<List<Movie>> fetchMovies({MovieLoadMode mode = MovieLoadMode.success});
}

class FakeMovieService implements MovieService {
  const FakeMovieService({this.delay = const Duration(seconds: 1)});
  final Duration delay;

  @override
  Future<List<Movie>> fetchMovies({
    MovieLoadMode mode = MovieLoadMode.success,
  }) async {
    // TODO(5주차 유저별 평점 조회 API): 이 호출 경계를 실제 API Service로 교체한다.
    await Future<void>.delayed(
      mode == MovieLoadMode.timeout ? const Duration(seconds: 4) : delay,
    );
    return switch (mode) {
      MovieLoadMode.success ||
      MovieLoadMode.timeout => List<Movie>.of(mockMovies),
      MovieLoadMode.empty => <Movie>[],
      MovieLoadMode.failure => throw const MovieLoadException(),
    };
  }
}
