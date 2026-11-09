import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/movie_list_view_model.dart';

import 'fakes/fake_tmdb_movie_service.dart';

List<int> _range(int start, int count) => [for (var i = 0; i < count; i++) start + i];

void main() {
  test('페이지 사이 중복을 제거하며 최대 30개까지만 모은다', () async {
    final service = FakeTmdbMovieService(
      discoverPages: [_range(1, 20), _range(11, 20), _range(31, 20)],
    );
    final viewModel = MovieListViewModel(service);

    await viewModel.loadInitial();

    expect(viewModel.status, MovieListLoadStatus.success);
    expect(viewModel.movies.map((movie) => movie.id), _range(1, 30));
    expect(service.requestedPages, [1, 2]);
  });

  test('결과가 30개보다 적으면 마지막 페이지까지만 요청하고 있는 만큼 보여준다', () async {
    final service = FakeTmdbMovieService(discoverPages: [_range(1, 5)]);
    final viewModel = MovieListViewModel(service);

    await viewModel.loadInitial();

    expect(viewModel.movies, hasLength(5));
    expect(service.requestedPages, [1]);
  });

  test('장르를 선택하면 with_genres 조건으로 page 1부터 다시 요청한다', () async {
    final service = FakeTmdbMovieService(discoverPages: [_range(1, 3)]);
    final viewModel = MovieListViewModel(service);
    await viewModel.loadInitial();

    await viewModel.selectGenre(28);
    expect(viewModel.selectedGenreId, 28);
    expect(service.requestedGenreIds.last, 28);
    expect(service.requestedPages.last, 1);

    await viewModel.selectGenre(null);
    expect(service.requestedGenreIds.last, isNull);
  });

  test('Discover 요청 중에는 장르를 바꿀 수 없다', () async {
    final service = FakeTmdbMovieService(discoverPages: [_range(1, 3)]);
    final viewModel = MovieListViewModel(service);
    await viewModel.loadInitial();

    final pending = viewModel.selectGenre(28);
    expect(viewModel.canChangeGenre, isFalse);
    await viewModel.selectGenre(99);
    await pending;

    expect(viewModel.selectedGenreId, 28);
    expect(service.requestedGenreIds, isNot(contains(99)));
    expect(viewModel.canChangeGenre, isTrue);
  });

  test('재시도해도 마지막으로 선택한 장르 조건을 유지한다', () async {
    final service = FakeTmdbMovieService(discoverPages: [_range(1, 3)]);
    final viewModel = MovieListViewModel(service);
    await viewModel.loadInitial();
    await viewModel.selectGenre(28);

    await viewModel.loadInitial();
    expect(service.requestedGenreIds.last, 28);
  });

  test('결과가 없으면 Empty 상태가 된다', () async {
    final service = FakeTmdbMovieService(discoverPages: [const []]);
    final viewModel = MovieListViewModel(service);

    await viewModel.loadInitial();

    expect(viewModel.status, MovieListLoadStatus.empty);
  });

  test('DTO 변환에 실패해도 Loading에 멈추지 않고 Error가 되어 장르를 다시 고를 수 있다', () async {
    final viewModel = MovieListViewModel(FakeTmdbMovieService(failWithParseError: true));

    await viewModel.loadInitial();

    expect(viewModel.status, MovieListLoadStatus.error);
    expect(viewModel.canChangeGenre, isTrue);
  });
}
