import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/movie_home_view_model.dart';

import 'fakes/fake_tmdb_movie_service.dart';

void main() {
  test('응답 전에 화면을 떠나 dispose돼도 오류 없이 끝난다', () async {
    final service = FakeTmdbMovieService(
      popularIds: [1, 2, 3],
      popularDelay: const Duration(milliseconds: 10),
    );
    final viewModel = MovieHomeViewModel(service);

    final pending = viewModel.loadPopular();
    viewModel.dispose();

    await expectLater(pending, completes);
  });

  test('DTO 변환에 실패해도 Loading에 멈추지 않고 Error가 된다', () async {
    final viewModel = MovieHomeViewModel(FakeTmdbMovieService(failWithParseError: true));

    await viewModel.loadPopular();

    expect(viewModel.status, MovieHomeLoadStatus.error);
  });
}
