import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';

import 'fakes/fake_rating_api_service.dart';
import 'fakes/fake_tmdb_movie_service.dart';

void main() {
  test('RatingDto는 comment가 null인 응답도 변환한다', () {
    final rating = RatingDto.fromJson({
      'ratingId': 3,
      'movieId': 13,
      'score': 3,
      'comment': null,
      'createdAt': '2026-11-02T19:00:19.459Z',
      'updatedAt': '2026-11-02T19:00:19.459Z',
    });
    expect(rating.comment, isNull);
    expect(rating.movieId, 13);
  });

  test('빈 배열이면 Empty 상태가 된다', () async {
    final viewModel = MyRatingsViewModel(
      FakeRatingApiService(),
      FakeTmdbMovieService(),
      sampleMemberId,
    );
    await viewModel.load();
    expect(viewModel.status, MyRatingsLoadStatus.empty);
  });

  test('평점이 있으면 TMDB 영화와 묶어 Success 상태가 되고, 같은 movieId는 한 번만 조회한다', () async {
    final tmdb = FakeTmdbMovieService();
    final viewModel = MyRatingsViewModel(
      FakeRatingApiService(ratings: [
        sampleRating(ratingId: 1, movieId: 550),
        sampleRating(ratingId: 2, movieId: 550),
      ]),
      tmdb,
      sampleMemberId,
    );
    await viewModel.load();
    await viewModel.load();

    expect(viewModel.status, MyRatingsLoadStatus.success);
    expect(viewModel.ratings.first.movie?.title, '영화 550');
    expect(tmdb.detailRequests, [550]);
    expect(viewModel.message, isNull);
  });

  test('TMDB에서 영화를 찾지 못해도 평점은 유지하고 안내 문구를 보여준다', () async {
    final viewModel = MyRatingsViewModel(
      FakeRatingApiService(ratings: [
        sampleRating(ratingId: 1, movieId: 550),
        sampleRating(ratingId: 2, movieId: 13),
      ]),
      FakeTmdbMovieService(missingMovieIds: {13}),
      sampleMemberId,
    );
    await viewModel.load();

    expect(viewModel.status, MyRatingsLoadStatus.success);
    expect(viewModel.ratings, hasLength(2));
    expect(viewModel.ratings.last.movie, isNull);
    expect(viewModel.message, isNotNull);
  });

  test('평점 조회가 실패하면 상태 코드별 문구와 함께 Error 상태가 된다', () async {
    final notFound = MyRatingsViewModel(
      FakeRatingApiService(failStatusCode: 404),
      FakeTmdbMovieService(),
      sampleMemberId,
    );
    await notFound.load();
    expect(notFound.status, MyRatingsLoadStatus.error);
    expect(notFound.message, '존재하지 않는 회원입니다.');

    final badRequest = MyRatingsViewModel(
      FakeRatingApiService(failStatusCode: 400),
      FakeTmdbMovieService(),
      sampleMemberId,
    );
    await badRequest.load();
    expect(badRequest.message, 'memberId 형식을 다시 확인해 주세요.');
  });
}
