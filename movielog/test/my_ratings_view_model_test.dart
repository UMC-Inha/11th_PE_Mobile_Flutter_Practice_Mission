import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';

import 'support.dart';

void main() {
  late FakeTmdbMovieService tmdb;
  late FakeMovieLogApiService api;

  setUp(() {
    tmdb = FakeTmdbMovieService(delay: Duration.zero);
    api = FakeMovieLogApiService();
  });

  MyRatingsViewModel createViewModel() => MyRatingsViewModel(api, tmdb);

  test('조회 대상 memberId는 학습용 상수 1이다', () async {
    final vm = createViewModel();
    await vm.load();
    expect(vm.memberId, sampleMemberId);
    expect(api.ratingMemberIds, [1]);
  });

  group('Loading · Success', () {
    test('idle → loading → success로 바뀌고, 각 평점에 TMDB 영화가 묶인다', () async {
      tmdb.moviesById
        ..[550] = movie(550, title: '파이트 클럽')
        ..[155] = movie(155, title: '다크 나이트');
      final vm = createViewModel();
      final seen = <MyRatingsLoadStatus>[];
      vm.addListener(() => seen.add(vm.status));
      expect(vm.status, MyRatingsLoadStatus.idle);

      await vm.load();

      expect(seen, [MyRatingsLoadStatus.loading, MyRatingsLoadStatus.success]);
      expect(vm.ratings.map((e) => e.rating.ratingId), [2, 1]);
      expect(vm.ratings.map((e) => e.movie?.title), ['다크 나이트', '파이트 클럽']);
      expect(vm.averageScore, 4.5);
      expect(vm.message, isNull);
    });

    test('같은 movieId는 한 번만 조회한다', () async {
      api.ratings = [
        memberRating(3, 550),
        memberRating(2, 550),
        memberRating(1, 155),
      ];
      tmdb.moviesById
        ..[550] = movie(550)
        ..[155] = movie(155);
      final vm = createViewModel();
      await vm.load();
      expect(tmdb.movieCalls.toList()..sort(), [155, 550]);
      expect(vm.ratings, hasLength(3));
    });

    test('다시 불러올 때 이미 아는 영화는 TMDB에 다시 묻지 않는다', () async {
      tmdb.moviesById
        ..[550] = movie(550)
        ..[155] = movie(155);
      final vm = createViewModel();
      await vm.load();
      tmdb.movieCalls.clear();
      await vm.load();
      expect(tmdb.movieCalls, isEmpty);
      expect(vm.status, MyRatingsLoadStatus.success);
    });
  });

  group('Empty', () {
    test('평점이 없는 회원(빈 배열)은 error가 아니라 empty다', () async {
      api.ratings = const [];
      final vm = createViewModel();
      await vm.load();
      expect(vm.status, MyRatingsLoadStatus.empty);
      expect(vm.ratings, isEmpty);
      expect(vm.message, isNull);
      expect(vm.averageScore, isNull);
      expect(tmdb.movieCalls, isEmpty);
    });
  });

  group('Error', () {
    test('통신 실패는 error와 안내 문구', () async {
      api.fail = true;
      final vm = createViewModel();
      await vm.load();
      expect(vm.status, MyRatingsLoadStatus.error);
      // 연결 오류는 loadErrorMessage의 네트워크 안내를 쓴다(404·400 문구와 구분된다).
      expect(vm.message, '네트워크 상태를 확인하고 다시 시도해 주세요.');
      expect(vm.ratings, isEmpty);
    });

    test('404(없는 회원)와 400(형식 오류)은 서로 다른 문구', () async {
      api.ratingsStatus = 404;
      final notFound = createViewModel();
      await notFound.load();
      expect(notFound.status, MyRatingsLoadStatus.error);
      expect(notFound.message, '존재하지 않는 회원입니다.');

      api.ratingsStatus = 400;
      final badRequest = createViewModel();
      await badRequest.load();
      expect(badRequest.status, MyRatingsLoadStatus.error);
      expect(badRequest.message, 'memberId 형식을 다시 확인해 주세요.');
      expect(badRequest.message, isNot(notFound.message));
    });

    test('error 뒤에 다시 불러오면 success가 되고 오류 문구가 지워진다', () async {
      tmdb.moviesById
        ..[550] = movie(550)
        ..[155] = movie(155);
      api.fail = true;
      final vm = createViewModel();
      await vm.load();
      expect(vm.status, MyRatingsLoadStatus.error);

      api.fail = false;
      await vm.load();
      expect(vm.status, MyRatingsLoadStatus.success);
      expect(vm.message, isNull);
    });
  });

  group('TMDB 영화 조회 실패는 평점을 지우지 않는다', () {
    test('TMDB가 404를 준 영화는 movie가 null이고 평점은 남으며 다시 묻지 않는다', () async {
      tmdb.moviesById[550] = movie(550, title: '파이트 클럽');
      tmdb.notFoundMovieIds.add(155);
      final vm = createViewModel();

      await vm.load();

      expect(vm.status, MyRatingsLoadStatus.success);
      expect(vm.ratings, hasLength(2));
      final missing = vm.ratings.firstWhere((e) => e.rating.movieId == 155);
      expect(missing.movie, isNull);
      expect(missing.rating.score, 4); // 평점은 그대로
      expect(vm.message, contains('일부 영화 정보를 가져오지 못해'));

      tmdb.movieCalls.clear();
      await vm.load();
      expect(tmdb.movieCalls, isEmpty); // 404도 캐시해서 다시 묻지 않는다
    });

    test('일시적인 네트워크 실패는 캐시하지 않아 다음 load에서 다시 시도한다', () async {
      tmdb.moviesById[550] = movie(550, title: '파이트 클럽');
      // 155는 404도 아니고 목록에도 없어 네트워크 실패처럼 던진다.
      final vm = createViewModel();
      await vm.load();
      expect(vm.status, MyRatingsLoadStatus.success);
      expect(
        vm.ratings.firstWhere((e) => e.rating.movieId == 155).movie,
        isNull,
      );
      expect(vm.message, isNotNull);

      tmdb.moviesById[155] = movie(155, title: '다크 나이트');
      tmdb.movieCalls.clear();
      await vm.load();

      expect(tmdb.movieCalls, [155]); // 성공한 550은 다시 묻지 않고, 실패한 155만 재시도
      expect(
        vm.ratings.firstWhere((e) => e.rating.movieId == 155).movie?.title,
        '다크 나이트',
      );
      expect(vm.message, isNull);
    });
  });

  group('늦게 도착한 응답', () {
    test('새 load가 시작되면 이전 응답은 버린다', () async {
      tmdb.moviesById
        ..[550] = movie(550)
        ..[155] = movie(155);
      final firstGate = Completer<void>();
      api.gate = firstGate;
      final vm = createViewModel();
      final first = vm.load(); // 응답이 게이트에 붙잡혀 있다
      await Future<void>.delayed(const Duration(milliseconds: 10));

      api.gate = null;
      api.ratings = [memberRating(9, 550)];
      await vm.load(); // 두 번째 요청이 먼저 끝난다
      expect(vm.ratings.map((e) => e.rating.ratingId), [9]);

      firstGate.complete(); // 첫 요청의 (옛) 응답이 뒤늦게 도착한다
      await first;
      expect(vm.ratings.map((e) => e.rating.ratingId), [9]);
      expect(vm.status, MyRatingsLoadStatus.success);
    });

    test('dispose 뒤에 도착한 응답은 알림을 보내지 않는다', () async {
      api.gate = Completer<void>();
      final vm = createViewModel();
      var notified = 0;
      vm.addListener(() => notified++);
      final pending = vm.load();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final before = notified;

      vm.dispose();
      api.gate!.complete();
      await pending;

      expect(notified, before);
    });
  });
}
