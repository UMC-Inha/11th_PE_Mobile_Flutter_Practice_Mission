import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/submit_status.dart';

import 'support.dart';

void main() {
  late FakeTmdbMovieService tmdb;
  late FakeMovieLogApiService api;

  setUp(() {
    tmdb = FakeTmdbMovieService(delay: Duration.zero);
    api = FakeMovieLogApiService();
    tmdb.moviesById
      ..[550] = movie(550, title: '파이트 클럽')
      ..[155] = movie(155, title: '다크 나이트');
  });

  group('MovieDetailViewModel.createRating', () {
    MovieDetailViewModel createVm({int? memberId = 101, int movieId = 551}) =>
        MovieDetailViewModel(
          tmdb,
          api,
          movieId: movieId,
          movie: movie(movieId),
          memberId: memberId,
        );

    test('성공: idle → submitting → success이고 요청의 movieId는 TMDB id다', () async {
      final vm = createVm();
      final seen = <SubmitStatus>[];
      vm.addListener(() => seen.add(vm.submitStatus));

      await vm.createRating(score: 4, comment: '  좋았다 ');

      expect(seen, [SubmitStatus.submitting, SubmitStatus.success]);
      expect(api.createdRatings.single.memberId, 101);
      expect(api.createdRatings.single.request.toJson(), {
        'movieId': 551,
        'score': 4,
        'comment': '좋았다',
      });
      expect(vm.myRating?.score, 4);
      expect(vm.submitMessage, isNull);
      // 등록만 하고 이 화면에서 목록을 다시 조회하지 않는다(조회는 마이페이지).
      expect(api.fetchCalls, 0);
    });

    test('회원가입 전(memberId null)에는 요청을 보내지 않고 안내한다', () async {
      final vm = createVm(memberId: null);
      expect(vm.canRate, isFalse);
      await vm.createRating(score: 5);
      expect(vm.submitStatus, SubmitStatus.error);
      expect(vm.submitMessage, '먼저 회원가입을 완료해 주세요.');
      expect(api.createdRatings, isEmpty);
    });

    test('409(이미 등록)·400·404는 서버 message를 그대로 담고 평점은 저장된 것으로 보지 않는다', () async {
      final cases = {
        409: '이미 이 영화에 평점을 남기셨습니다.',
        400: '별점은 5점 이하여야 합니다.',
        404: '존재하지 않는 유저입니다.', // 등록에서의 404는 "유저"
      };
      for (final entry in cases.entries) {
        final vm = createVm();
        api.failures['createRating'] = FakeMovieLogApiService.badResponse(
          '/members/101/ratings',
          entry.key,
          message: entry.value,
        );
        await vm.createRating(score: 4);
        expect(vm.submitStatus, SubmitStatus.error, reason: '${entry.key}');
        expect(vm.submitMessage, entry.value);
        expect(vm.myRating, isNull);
      }
    });

    test('같은 영화에 두 번 등록하면 두 번째는 409 문구로 실패한다', () async {
      api.ratings = [];
      final vm = createVm();
      await vm.createRating(score: 4);
      expect(vm.submitStatus, SubmitStatus.success);
      await vm.createRating(score: 5);
      expect(vm.submitStatus, SubmitStatus.error);
      expect(vm.submitMessage, '이미 이 영화에 평점을 남기셨습니다.');
      expect(vm.myRating?.score, 4); // 첫 번째 결과가 그대로 남는다
    });

    test('서버가 꺼졌을 때는 통신 실패 문구다', () async {
      final vm = createVm();
      api.failures['createRating'] = FakeTmdbMovieService.failure('/x');
      await vm.createRating(score: 3);
      expect(vm.submitMessage, '네트워크 상태를 확인하고 다시 시도해 주세요.');
    });

    test('계약에서 벗어난 응답(StateError)은 저장 여부를 알 수 없다고 안내한다', () async {
      final vm = createVm();
      api.failures['createRating'] = StateError('예상하지 못한 등록 응답: 200');
      await vm.createRating(score: 3);
      expect(vm.submitStatus, SubmitStatus.error);
      expect(vm.submitMessage, contains('마이페이지에서 등록 여부를 확인'));
    });

    test('요청 중 중복 호출은 무시한다', () async {
      api.writeGate = Completer<void>();
      final vm = createVm();
      final first = vm.createRating(score: 4);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await vm.createRating(score: 4);
      expect(api.createdRatings, hasLength(1));
      api.writeGate!.complete();
      await first;
      expect(vm.submitStatus, SubmitStatus.success);
    });

    test('화면이 사라진 뒤 도착한 응답은 상태를 건드리지 않는다', () async {
      api.writeGate = Completer<void>();
      final vm = createVm();
      final pending = vm.createRating(score: 4);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      vm.dispose();
      api.writeGate!.complete();
      await pending; // dispose 뒤 notifyListeners가 불리면 예외가 난다
      expect(vm.myRating, isNull);
    });
  });

  group('MyRatingsViewModel 수정·삭제', () {
    MyRatingsViewModel createVm() =>
        MyRatingsViewModel(api, tmdb, memberId: 101);

    Future<MyRatingsViewModel> loaded() async {
      final vm = createVm();
      await vm.load();
      return vm;
    }

    test('수정: PATCH를 보내고 목록을 다시 조회하며, 그동안 로딩 화면으로 바뀌지 않는다', () async {
      final vm = await loaded();
      final seen = <MyRatingsLoadStatus>[];
      vm.addListener(() => seen.add(vm.status));

      await vm.updateRating(ratingId: 1, score: 3, comment: ' 다시 보니 별로 ');

      expect(api.updatedRatings.single.memberId, 101);
      expect(api.updatedRatings.single.ratingId, 1);
      expect(api.updatedRatings.single.request.toJson(), {
        'score': 3,
        'comment': '다시 보니 별로',
      });
      final updated = vm.ratings.firstWhere((e) => e.rating.ratingId == 1);
      expect(updated.rating.score, 3);
      expect(updated.rating.comment, '다시 보니 별로');
      expect(seen, isNot(contains(MyRatingsLoadStatus.loading)));
      expect(vm.status, MyRatingsLoadStatus.success);
      expect(vm.refreshWarning, isNull);
    });

    test('수정: 코멘트를 비우면 null로 보내 후기가 지워진다', () async {
      final vm = await loaded();
      await vm.updateRating(ratingId: 1, score: 5);
      expect(api.updatedRatings.single.request.toJson()['comment'], isNull);
      final updated = vm.ratings.firstWhere((e) => e.rating.ratingId == 1);
      expect(updated.rating.comment, isNull);
    });

    test('수정 실패(403·404)는 서버 문구로 던지고, 화면의 목록을 서버 상태에 맞춰 다시 조회한다', () async {
      for (final status in [403, 404]) {
        api = FakeMovieLogApiService();
        final vm = await loaded();
        final before = api.fetchCalls;
        api.failures['updateRating'] = FakeMovieLogApiService.badResponse(
          '/members/101/ratings/1',
          status,
          message: status == 403
              ? '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'
              : '존재하지 않는 평점입니다.',
        );

        await expectLater(
          vm.updateRating(ratingId: 1, score: 3),
          throwsA(
            isA<RatingSaveException>().having(
              (e) => e.message,
              'message',
              status == 403
                  ? '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'
                  : '존재하지 않는 평점입니다.',
            ),
          ),
        );
        expect(api.fetchCalls, before + 1, reason: '$status는 다시 조회한다');
      }
    });

    test('수정 실패(400·409·통신 실패)는 목록을 다시 조회하지 않는다', () async {
      final vm = await loaded();
      final before = api.fetchCalls;
      api.failures['updateRating'] = FakeMovieLogApiService.badResponse(
        '/members/101/ratings/1',
        400,
        message: '별점은 5점 이하여야 합니다.',
      );
      await expectLater(
        vm.updateRating(ratingId: 1, score: 3),
        throwsA(isA<RatingSaveException>()),
      );
      api.failures['updateRating'] = FakeTmdbMovieService.failure('/x');
      await expectLater(
        vm.updateRating(ratingId: 1, score: 3),
        throwsA(
          isA<RatingSaveException>().having(
            (e) => e.message,
            'message',
            '네트워크 상태를 확인하고 다시 시도해 주세요.',
          ),
        ),
      );
      expect(api.fetchCalls, before);
      expect(vm.status, MyRatingsLoadStatus.success); // 목록은 그대로
    });

    test('저장은 성공했는데 재조회만 실패하면 쓰기는 실패가 아니고, 조회만 다시 시도한다', () async {
      final vm = await loaded();
      api.failFetchTimes = 1; // 다음 GET 한 번만 실패

      // 예외 없이 끝난다 = Dialog는 저장 성공으로 닫힌다.
      await vm.updateRating(ratingId: 1, score: 2, comment: '저장은 됐다');

      expect(api.updatedRatings, hasLength(1));
      expect(vm.status, MyRatingsLoadStatus.error);
      expect(vm.refreshWarning, '저장은 완료됐지만 목록을 불러오지 못했습니다. 조회만 다시 시도해 주세요.');

      // "다시 시도"는 GET만 다시 보낸다. 같은 PATCH를 또 보내지 않는다.
      await vm.load();
      expect(api.updatedRatings, hasLength(1));
      expect(vm.status, MyRatingsLoadStatus.success);
      expect(vm.refreshWarning, isNull);
      final updated = vm.ratings.firstWhere((e) => e.rating.ratingId == 1);
      expect(updated.rating.score, 2);
      expect(updated.rating.comment, '저장은 됐다');
    });

    test('삭제: DELETE를 보내고 목록에서 사라지며 마지막 항목을 지우면 Empty다', () async {
      final vm = await loaded();
      await vm.deleteRating(2);
      expect(api.deletedRatings.single, (memberId: 101, ratingId: 2));
      expect(vm.ratings.map((e) => e.rating.ratingId), [1]);
      expect(vm.status, MyRatingsLoadStatus.success);

      await vm.deleteRating(1);
      expect(vm.ratings, isEmpty);
      expect(vm.status, MyRatingsLoadStatus.empty);
    });

    test('삭제 실패(404): 서버 문구로 던지고 목록을 다시 조회해 사라진 항목을 맞춘다', () async {
      final vm = await loaded();
      api.ratings = api.ratings.where((r) => r.ratingId != 2).toList();
      // 다른 곳에서 이미 지워졌는데 화면에는 아직 남아 있다.
      expect(vm.ratings.map((e) => e.rating.ratingId), contains(2));

      await expectLater(
        vm.deleteRating(2),
        throwsA(
          isA<RatingSaveException>().having(
            (e) => e.message,
            'message',
            '존재하지 않는 평점입니다.',
          ),
        ),
      );
      expect(vm.ratings.map((e) => e.rating.ratingId), [1]);
    });

    test('삭제는 성공했는데 재조회만 실패하면 refreshWarning으로 알린다', () async {
      final vm = await loaded();
      api.failFetchTimes = 1;
      await vm.deleteRating(1);
      expect(api.deletedRatings, hasLength(1));
      expect(vm.status, MyRatingsLoadStatus.error);
      expect(vm.refreshWarning, contains('저장은 완료됐지만'));
      await vm.load();
      expect(vm.ratings.map((e) => e.rating.ratingId), [2]);
    });

    test('수정 중 화면이 사라져도 예외 없이 끝난다', () async {
      final vm = await loaded();
      api.writeGate = Completer<void>();
      final pending = vm.updateRating(ratingId: 1, score: 3);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      vm.dispose();
      api.writeGate!.complete();
      await pending;
    });
  });

  group('MyRatingsViewModel 편집 · 다중 선택 삭제 (Challenge)', () {
    late MyRatingsViewModel vm;

    setUp(() async {
      api.ratings = [
        memberRating(4, 155, comment: null),
        memberRating(3, 550),
        memberRating(2, 27205),
        memberRating(1, 680),
      ];
      tmdb.moviesById
        ..[27205] = movie(27205)
        ..[680] = movie(680);
      vm = MyRatingsViewModel(api, tmdb, memberId: 101);
      await vm.load();
    });

    test('편집 모드에 들어갔다 취소하면 선택이 해제된다', () {
      expect(vm.isEditing, isFalse);
      vm.startEditing();
      expect(vm.isEditing, isTrue);
      vm.toggleSelection(3);
      vm.toggleSelection(1);
      expect(vm.selectedRatingIds, {3, 1});
      vm.toggleSelection(3); // 다시 누르면 선택 해제
      expect(vm.selectedRatingIds, {1});

      vm.cancelEditing();
      expect(vm.isEditing, isFalse);
      expect(vm.selectedRatingIds, isEmpty);
    });

    test('편집 모드가 아니면 선택되지 않는다', () {
      vm.toggleSelection(3);
      expect(vm.selectedRatingIds, isEmpty);
    });

    test('선택한 평점을 모두 지우면 목록에서 사라지고 기본 목록으로 돌아간다', () async {
      vm.startEditing();
      vm
        ..toggleSelection(4)
        ..toggleSelection(2);
      final seenDeleting = <bool>[];
      vm.addListener(() => seenDeleting.add(vm.isDeletingSelected));

      final result = await vm.deleteSelectedRatings();

      expect(result, (deleted: 2, failed: 0));
      expect(api.deletedRatings.map((e) => e.ratingId), [4, 2]); // 선택 순서대로
      expect(vm.ratings.map((e) => e.rating.ratingId), [3, 1]);
      expect(vm.selectedRatingIds, isEmpty);
      expect(vm.isEditing, isFalse);
      expect(vm.isDeletingSelected, isFalse);
      expect(seenDeleting.first, isTrue); // 시작하자마자 로딩 오버레이가 켜진다
      expect(seenDeleting.last, isFalse);
    });

    test('일부만 실패하면 성공한 항목만 사라지고 실패한 항목은 선택이 유지된다', () async {
      api.failDeleteIds.add(2);
      vm.startEditing();
      vm
        ..toggleSelection(4)
        ..toggleSelection(2)
        ..toggleSelection(1);

      // 원본 Set을 순회하며 지우면 ConcurrentModificationError가 난다. 복사본을 돌아야 한다.
      final result = await vm.deleteSelectedRatings();

      expect(result, (deleted: 2, failed: 1));
      expect(vm.ratings.map((e) => e.rating.ratingId), [3, 2]);
      expect(vm.selectedRatingIds, {2}); // 실패한 항목만 선택 상태 유지
      expect(vm.isEditing, isTrue); // 다시 시도할 수 있게 편집 모드 유지
      expect(vm.isDeletingSelected, isFalse);

      // 서버가 회복되면 남은 선택으로 다시 시도해 마저 지운다.
      api.failDeleteIds.clear();
      final retry = await vm.deleteSelectedRatings();
      expect(retry, (deleted: 1, failed: 0));
      expect(vm.ratings.map((e) => e.rating.ratingId), [3]);
      expect(vm.isEditing, isFalse);
    });

    test('삭제 중에는 다시 호출해도 무시하고, 편집 모드를 바꾸거나 선택을 바꿀 수 없다', () async {
      vm.startEditing();
      vm.toggleSelection(4);
      api.writeGate = Completer<void>();
      final running = vm.deleteSelectedRatings();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(vm.isDeletingSelected, isTrue);

      expect(await vm.deleteSelectedRatings(), (deleted: 0, failed: 0));
      vm.cancelEditing();
      vm.toggleSelection(3);
      expect(vm.isEditing, isTrue);
      expect(vm.selectedRatingIds, {4});
      expect(api.deletedRatings, hasLength(1));

      api.writeGate!.complete();
      await running;
      expect(vm.isDeletingSelected, isFalse);
    });

    test('선택이 없으면 아무 요청도 보내지 않는다', () async {
      vm.startEditing();
      expect(await vm.deleteSelectedRatings(), (deleted: 0, failed: 0));
      expect(api.deletedRatings, isEmpty);
    });

    test('삭제는 성공했지만 재조회가 실패해도 삭제 결과는 그대로 돌려준다', () async {
      vm.startEditing();
      vm.toggleSelection(4);
      api.failFetchTimes = 1;
      final result = await vm.deleteSelectedRatings();
      expect(result, (deleted: 1, failed: 0));
      expect(vm.refreshWarning, contains('저장은 완료됐지만'));
      expect(vm.status, MyRatingsLoadStatus.error);
    });

    test('다시 조회했을 때 서버에서 사라진 평점은 선택 목록에서도 빠진다', () async {
      vm.startEditing();
      vm
        ..toggleSelection(3)
        ..toggleSelection(1);
      api.ratings = api.ratings.where((r) => r.ratingId != 3).toList();
      await vm.load();
      expect(vm.selectedRatingIds, {1});
    });
  });
}
