import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/movielog_dtos.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/rating_error.dart';
import 'package:movielog/view_models/session_ratings.dart';
import 'package:movielog/view_models/submit_status.dart';

import 'support.dart';

const _email = 'kevin@umc.com';
const _password = 'Password1234!';

/// ViewModel 테스트에 필요한 의존성 묶음. 로그인은 진짜 AuthViewModel로 한다.
class _Env {
  final tmdb = FakeTmdbMovieService(delay: Duration.zero);
  final ratingApi = FakeRatingApiService();
  final storage = FakeTokenStorage();
  final authApi = FakeAuthApiService();
  final memberApi = FakeMemberApiService();
  late final AuthViewModel auth = AuthViewModel(authApi, memberApi, storage);
  late final SessionRatings session = SessionRatings(auth);

  Future<void> signIn() => auth.login(_email, _password);

  /// 서버(Fake)와 이번 세션 목록 양쪽에 평점을 심는다. 입력 순서가 목록 순서다.
  void seed(List<MemberRatingDto> ratings) {
    for (final rating in ratings.reversed) {
      ratingApi.serverRatings[rating.ratingId] = rating;
      session.add(rating, version: auth.sessionVersion);
    }
  }

  void dispose() {
    session.dispose();
    auth.dispose();
  }
}

Matcher _savesWith(String message) => throwsA(
  isA<RatingSaveException>().having((e) => e.message, 'message', message),
);

void main() {
  late _Env env;

  setUp(() {
    env = _Env();
    env.tmdb.moviesById
      ..[550] = movie(550, title: '파이트 클럽')
      ..[155] = movie(155, title: '다크 나이트');
  });

  tearDown(() => env.dispose());

  group('MovieDetailViewModel.createRating', () {
    MovieDetailViewModel createVm({int movieId = 551}) => MovieDetailViewModel(
      env.tmdb,
      env.ratingApi,
      env.auth,
      env.session,
      movieRecordApi: FakeMovieRecordApiService(
        ratingApi: env.ratingApi,
        favoriteApi: FakeFavoriteApiService(),
      ),
      movieId: movieId,
      movie: movie(movieId),
    );

    test(
      '성공: idle → submitting → success이고 요청의 movieId는 TMDB id이며 memberId는 없다',
      () async {
        await env.signIn();
        final vm = createVm();
        addTearDown(vm.dispose);
        final seen = <SubmitStatus>[];
        vm.addListener(() => seen.add(vm.submitStatus));

        await vm.createRating(score: 4, comment: '  좋았다 ');

        expect(seen, [SubmitStatus.submitting, SubmitStatus.success]);
        expect(env.ratingApi.createdRequests.single.toJson(), {
          'movieId': 551,
          'score': 4,
          'comment': '좋았다',
        });
        expect(vm.myRating?.score, 4);
        expect(vm.submitMessage, isNull);
        // 응답으로 받은 평점이 이번 세션 목록에 들어가 마이페이지에서 수정·삭제할 수 있다.
        expect(env.session.ratings.single.movieId, 551);
      },
    );

    test('로그인하지 않았으면 요청을 보내지 않고 안내한다', () async {
      final vm = createVm();
      addTearDown(vm.dispose);
      expect(vm.canRate, isFalse);

      await vm.createRating(score: 5);

      expect(vm.submitStatus, SubmitStatus.error);
      expect(vm.submitMessage, '로그인이 필요해요.');
      expect(env.ratingApi.createdRequests, isEmpty);
    });

    test('409(이미 등록)·400·404는 서버 message를 그대로 담고 저장된 것으로 보지 않는다', () async {
      await env.signIn();
      final cases = {
        409: '이미 이 영화에 평점을 남기셨습니다.',
        400: '별점은 5점 이하여야 합니다.',
        404: '존재하지 않는 영화입니다.',
      };
      for (final entry in cases.entries) {
        final vm = createVm();
        addTearDown(vm.dispose);
        env.ratingApi.failures['create'] = apiFailure(
          '/ratings',
          entry.key,
          code: 'RATING${entry.key}_1',
          message: entry.value,
        );
        await vm.createRating(score: 4);
        expect(vm.submitStatus, SubmitStatus.error, reason: '${entry.key}');
        expect(vm.submitMessage, entry.value);
        expect(vm.myRating, isNull);
      }
      expect(env.session.ratings, isEmpty);
      expect(env.auth.status, AuthStatus.signedIn, reason: '입력 오류는 로그아웃이 아니다');
    });

    test('같은 영화에 두 번 등록하면 두 번째는 409 문구로 실패하고 첫 결과가 남는다', () async {
      await env.signIn();
      final vm = createVm();
      addTearDown(vm.dispose);
      await vm.createRating(score: 4);
      expect(vm.submitStatus, SubmitStatus.success);

      await vm.createRating(score: 5);
      expect(vm.submitStatus, SubmitStatus.error);
      expect(vm.submitMessage, '이미 이 영화에 평점을 남기셨습니다.');
      expect(vm.myRating?.score, 4);
      expect(env.session.ratings, hasLength(1));
    });

    test('403은 안내만 하고 로그아웃하지 않는다(권한 부족은 만료가 아니다)', () async {
      await env.signIn();
      final vm = createVm();
      addTearDown(vm.dispose);
      env.ratingApi.failures['create'] = apiFailure(
        '/ratings',
        403,
        code: 'RATING403_1',
        message: '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
      );

      await vm.createRating(score: 4);

      expect(vm.submitMessage, contains('본인이 작성한'));
      expect(env.auth.status, AuthStatus.signedIn);
      expect(env.auth.sessionExpired, isFalse);
      expect(env.storage.token, isNotNull);
    });

    test('토큰 만료(AUTH401_3)면 세션을 정리하고 만료 문구를 보여준다', () async {
      await env.signIn();
      final vm = createVm();
      addTearDown(vm.dispose);
      env.ratingApi.failures['create'] = apiFailure(
        '/ratings',
        401,
        code: 'AUTH401_3',
        message: '토큰이 만료되었습니다.',
      );

      await vm.createRating(score: 4);

      expect(vm.submitStatus, SubmitStatus.error);
      expect(vm.submitMessage, '로그인이 만료됐어요. 다시 로그인해 주세요.');
      expect(env.auth.status, AuthStatus.signedOut);
      expect(env.auth.sessionExpired, isTrue);
      expect(env.storage.token, isNull);
    });

    test('서버가 꺼졌을 때는 통신 실패 문구이고 토큰은 그대로다', () async {
      await env.signIn();
      final vm = createVm();
      addTearDown(vm.dispose);
      env.ratingApi.failures['create'] = networkFailure('/ratings');

      await vm.createRating(score: 3);

      expect(vm.submitMessage, '네트워크 상태를 확인하고 다시 시도해 주세요.');
      expect(env.auth.status, AuthStatus.signedIn);
      expect(env.storage.token, isNotNull);
    });

    test('계약에서 벗어난 응답(StateError)은 저장 여부를 알 수 없다고 안내한다', () async {
      await env.signIn();
      final vm = createVm();
      addTearDown(vm.dispose);
      env.ratingApi.failures['create'] = StateError('예상하지 못한 등록 응답: 200');

      await vm.createRating(score: 3);

      expect(vm.submitStatus, SubmitStatus.error);
      expect(vm.submitMessage, unknownWriteResultMessage);
      expect(env.session.ratings, isEmpty);
    });

    test('요청 중 중복 호출은 무시한다', () async {
      await env.signIn();
      env.ratingApi.writeGate = Completer<void>();
      final vm = createVm();
      addTearDown(vm.dispose);
      final first = vm.createRating(score: 4);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      await vm.createRating(score: 4);
      expect(env.ratingApi.createdRequests, hasLength(1));

      env.ratingApi.writeGate!.complete();
      await first;
      expect(vm.submitStatus, SubmitStatus.success);
    });

    test('화면이 사라진 뒤 도착한 응답은 상태를 건드리지 않는다', () async {
      await env.signIn();
      env.ratingApi.writeGate = Completer<void>();
      final vm = createVm();
      final pending = vm.createRating(score: 4);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      vm.dispose();
      env.ratingApi.writeGate!.complete();
      await pending; // dispose 뒤 notifyListeners가 불리면 예외가 난다
      expect(vm.myRating, isNull);
    });

    test('등록 중 로그아웃하면 늦게 온 성공 응답이 새 세션 목록에 섞이지 않는다', () async {
      await env.signIn();
      env.ratingApi.writeGate = Completer<void>();
      final vm = createVm();
      addTearDown(vm.dispose);
      final pending = vm.createRating(score: 4);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      await env.auth.logout();
      env.ratingApi.writeGate!.complete();
      await pending;

      expect(env.session.ratings, isEmpty);
      expect(vm.myRating, isNull);
      expect(env.auth.status, AuthStatus.signedOut);
    });

    test('등록 중 로그아웃하고 다시 로그인하면 지난 세션의 늦은 실패는 반영하지 않는다', () async {
      await env.signIn();
      env.ratingApi.writeGate = Completer<void>();
      env.ratingApi.failures['create'] = apiFailure(
        '/ratings',
        401,
        code: 'AUTH401_3',
        message: '토큰이 만료되었습니다.',
      );
      final vm = createVm();
      addTearDown(vm.dispose);
      final pending = vm.createRating(score: 4);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      await env.auth.logout();
      await env.signIn(); // 새 로그인(다른 세션)
      final newToken = env.storage.token;
      env.ratingApi.writeGate!.complete();
      await pending;

      // 지난 세션의 401이 새 로그인을 지우면 안 된다.
      expect(env.auth.status, AuthStatus.signedIn);
      expect(env.auth.sessionExpired, isFalse);
      expect(env.storage.token, newToken);
      expect(vm.submitMessage, isNull);
    });
  });

  group('SessionRatings', () {
    test('새로 등록한 평점이 위로 오고, 같은 ratingId는 교체된다', () async {
      await env.signIn();
      final v = env.auth.sessionVersion;
      env.session
        ..add(memberRating(1, 550), version: v)
        ..add(memberRating(2, 155), version: v);
      expect(env.session.ratings.map((e) => e.ratingId), [2, 1]);

      env.session.add(memberRating(1, 550, score: 2), version: v);
      expect(env.session.ratings.map((e) => e.ratingId), [1, 2]);
      expect(env.session.ratings.first.score, 2);
    });

    test('로그아웃·다른 계정 로그인이면 비워지고, 이전 세션의 쓰기는 무시한다', () async {
      await env.signIn();
      final oldVersion = env.auth.sessionVersion;
      env.session.add(memberRating(1, 550), version: oldVersion);
      expect(env.session.ratings, hasLength(1));

      await env.auth.logout();
      expect(env.session.ratings, isEmpty);

      await env.signIn();
      expect(
        env.session.add(memberRating(9, 155), version: oldVersion),
        isFalse,
      );
      expect(
        env.session.replace(memberRating(9, 155), version: oldVersion),
        isFalse,
      );
      expect(env.session.remove(9, version: oldVersion), isFalse);
      expect(env.session.ratings, isEmpty);
    });

    test('로그인하지 않은 상태에서는 현재 version이어도 받지 않는다', () {
      expect(
        env.session.add(memberRating(1, 550), version: env.auth.sessionVersion),
        isFalse,
      );
      expect(env.session.ratings, isEmpty);
    });
  });

  group('MyRatingsViewModel 로드·표시', () {
    MyRatingsViewModel createVm() =>
        MyRatingsViewModel(env.ratingApi, env.tmdb, env.auth, env.session);

    test('세션에 평점이 없으면 비어 있고 서버 목록은 읽지 않는다', () async {
      await env.signIn();
      final vm = createVm();
      addTearDown(vm.dispose);
      await vm.loadMovies();
      expect(vm.isEmpty, isTrue);
      expect(vm.averageScore, isNull);
      expect(env.tmdb.movieCalls, isEmpty);
    });

    test('TMDB에서 제목·포스터를 가져와 평점과 묶고 평균을 계산한다', () async {
      await env.signIn();
      env.seed([
        memberRating(2, 155, score: 4),
        memberRating(1, 550, score: 5),
      ]);
      final vm = createVm();
      addTearDown(vm.dispose);

      await vm.loadMovies();

      expect(vm.ratings.map((e) => e.movie?.title), ['다크 나이트', '파이트 클럽']);
      expect(vm.averageScore, 4.5);
      expect(vm.message, isNull);
    });

    test('TMDB에서 못 찾은 영화도 평점은 남기고 안내 문구를 보여준다', () async {
      await env.signIn();
      env.seed([memberRating(1, 999, score: 3)]);
      env.tmdb.notFoundMovieIds.add(999);
      final vm = createVm();
      addTearDown(vm.dispose);

      await vm.loadMovies();

      expect(vm.ratings.single.movie, isNull);
      expect(vm.ratings.single.rating.movieId, 999);
      expect(vm.message, contains('일부 영화 정보'));
    });

    test('일시적 TMDB 실패는 캐시하지 않아 다음 로드에서 다시 시도한다', () async {
      await env.signIn();
      env.seed([memberRating(1, 777)]);
      final vm = createVm();
      addTearDown(vm.dispose);
      await vm.loadMovies(); // 777은 아직 목록에 없어 실패한다
      expect(vm.ratings.single.movie, isNull);

      env.tmdb.moviesById[777] = movie(777, title: '뒤늦게 찾은 영화');
      await vm.loadMovies();
      expect(vm.ratings.single.movie?.title, '뒤늦게 찾은 영화');
      expect(vm.message, isNull);
    });

    test('같은 영화는 한 번만 조회한다', () async {
      await env.signIn();
      env.seed([memberRating(1, 550)]);
      final vm = createVm();
      addTearDown(vm.dispose);
      await vm.loadMovies();
      await vm.loadMovies();
      expect(env.tmdb.movieCalls.where((id) => id == 550), hasLength(1));
    });

    test('영화 정보를 기다리는 동안 화면이 사라져도 dispose 뒤에는 알리지 않는다', () async {
      await env.signIn();
      env.seed([memberRating(1, 550)]);
      env.tmdb.gate = Completer<void>();
      final vm = createVm();
      final loading = vm.loadMovies();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      vm.dispose();
      env.tmdb.gate!.complete();
      await loading; // dispose 뒤 notifyListeners가 불리면 예외가 난다
    });

    test('다른 화면에서 새로 등록한 평점도 영화 정보를 가져와 보여준다', () async {
      await env.signIn();
      final vm = createVm();
      addTearDown(vm.dispose);
      await vm.loadMovies();

      env.session.add(memberRating(5, 155), version: env.auth.sessionVersion);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(vm.ratings.single.movie?.title, '다크 나이트');
    });
  });

  group('MyRatingsViewModel 수정·삭제', () {
    late MyRatingsViewModel vm;

    setUp(() async {
      await env.signIn();
      env.seed([
        memberRating(2, 155, score: 4),
        memberRating(1, 550, score: 5),
      ]);
      vm = MyRatingsViewModel(env.ratingApi, env.tmdb, env.auth, env.session);
      await vm.loadMovies();
    });

    tearDown(() => vm.dispose());

    test('수정: PATCH를 보내고 응답으로 받은 평점으로 목록을 바꾼다(재조회 없음)', () async {
      await vm.updateRating(ratingId: 1, score: 3, comment: ' 다시 보니 별로 ');

      expect(env.ratingApi.updatedCalls.single.ratingId, 1);
      expect(env.ratingApi.updatedCalls.single.request.toJson(), {
        'score': 3,
        'comment': '다시 보니 별로',
      });
      final updated = vm.ratings.firstWhere((e) => e.rating.ratingId == 1);
      expect(updated.rating.score, 3);
      expect(updated.rating.comment, '다시 보니 별로');
      // 자리는 그대로고 다른 평점은 건드리지 않는다.
      expect(vm.ratings.map((e) => e.rating.ratingId), [2, 1]);
      expect(vm.ratings.first.rating.score, 4);
    });

    test('수정: 코멘트를 비우면 null로 보내 후기가 지워진다', () async {
      await vm.updateRating(ratingId: 1, score: 5);
      expect(
        env.ratingApi.updatedCalls.single.request.toJson()['comment'],
        isNull,
      );
      final updated = vm.ratings.firstWhere((e) => e.rating.ratingId == 1);
      expect(updated.rating.comment, isNull);
    });

    test('수정 실패(400·409·통신 실패)는 서버 문구로 던지고 목록은 그대로다', () async {
      env.ratingApi.failures['update'] = apiFailure(
        '/ratings/1',
        400,
        code: 'RATING400_1',
        message: '별점은 5점 이하여야 합니다.',
      );
      await expectLater(
        vm.updateRating(ratingId: 1, score: 3),
        _savesWith('별점은 5점 이하여야 합니다.'),
      );

      env.ratingApi.failures['update'] = networkFailure('/ratings/1');
      await expectLater(
        vm.updateRating(ratingId: 1, score: 3),
        _savesWith('네트워크 상태를 확인하고 다시 시도해 주세요.'),
      );

      expect(vm.ratings.map((e) => e.rating.ratingId), [2, 1]);
      expect(vm.ratings.last.rating.score, 5);
      expect(env.auth.status, AuthStatus.signedIn);
    });

    test('수정 403은 서버 문구로 안내하고 로그아웃하지 않으며 항목도 그대로 둔다', () async {
      env.ratingApi.failures['update'] = apiFailure(
        '/ratings/1',
        403,
        code: 'RATING403_1',
        message: '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
      );
      await expectLater(
        vm.updateRating(ratingId: 1, score: 3),
        _savesWith('본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'),
      );
      expect(env.auth.status, AuthStatus.signedIn);
      expect(env.auth.sessionExpired, isFalse);
      expect(env.storage.token, isNotNull);
      expect(vm.ratings.map((e) => e.rating.ratingId), [2, 1]);
    });

    test('수정 404면 이미 사라진 평점이므로 목록에서도 치운다', () async {
      env.ratingApi.serverRatings.remove(1); // 다른 곳에서 이미 지워졌다
      await expectLater(
        vm.updateRating(ratingId: 1, score: 3),
        _savesWith('해당 평점을 찾을 수 없습니다.'),
      );
      expect(vm.ratings.map((e) => e.rating.ratingId), [2]);
    });

    test('수정 401(AUTH401_3)은 세션을 정리하고 만료 문구로 던진다', () async {
      env.ratingApi.failures['update'] = apiFailure(
        '/ratings/1',
        401,
        code: 'AUTH401_3',
        message: '토큰이 만료되었습니다.',
      );
      await expectLater(
        vm.updateRating(ratingId: 1, score: 3),
        _savesWith('로그인이 만료됐어요. 다시 로그인해 주세요.'),
      );
      expect(env.auth.status, AuthStatus.signedOut);
      expect(env.auth.sessionExpired, isTrue);
      expect(env.session.ratings, isEmpty);
    });

    test('계약에서 벗어난 응답은 저장 결과를 알 수 없다고 던진다', () async {
      env.ratingApi.failures['update'] = StateError('평점 result가 없습니다.');
      await expectLater(
        vm.updateRating(ratingId: 1, score: 3),
        _savesWith(unknownWriteResultMessage),
      );
    });

    test('삭제: DELETE를 보내고 목록에서 사라지며 마지막 항목을 지우면 Empty다', () async {
      await vm.deleteRating(2);
      expect(env.ratingApi.deletedIds, [2]);
      expect(vm.ratings.map((e) => e.rating.ratingId), [1]);
      expect(vm.isEmpty, isFalse);

      await vm.deleteRating(1);
      expect(vm.ratings, isEmpty);
      expect(vm.isEmpty, isTrue);
    });

    test('삭제 404면 서버 문구로 던지고 화면에 남은 항목을 치운다', () async {
      env.ratingApi.serverRatings.remove(2);
      await expectLater(vm.deleteRating(2), _savesWith('해당 평점을 찾을 수 없습니다.'));
      expect(vm.ratings.map((e) => e.rating.ratingId), [1]);
    });

    test('삭제 401은 세션을 정리하고, 403은 로그아웃하지 않는다', () async {
      env.ratingApi.failures['delete'] = apiFailure(
        '/ratings/2',
        403,
        code: 'RATING403_1',
        message: '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
      );
      await expectLater(
        vm.deleteRating(2),
        _savesWith('본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'),
      );
      expect(env.auth.status, AuthStatus.signedIn);

      env.ratingApi.failures['delete'] = apiFailure(
        '/ratings/2',
        401,
        code: 'AUTH401_2',
        message: '유효하지 않은 토큰입니다.',
      );
      await expectLater(
        vm.deleteRating(2),
        _savesWith('로그인이 만료됐어요. 다시 로그인해 주세요.'),
      );
      expect(env.auth.status, AuthStatus.signedOut);
    });

    test('수정 중 로그아웃하면 늦게 온 성공 응답이 목록을 되살리지 못한다', () async {
      env.ratingApi.writeGate = Completer<void>();
      final pending = vm.updateRating(ratingId: 1, score: 3);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      await env.auth.logout();
      env.ratingApi.writeGate!.complete();
      await pending;

      expect(env.session.ratings, isEmpty);
      expect(vm.ratings, isEmpty);
    });

    test('로그인하지 않은 상태의 수정·삭제는 요청 없이 로그인 안내로 던진다', () async {
      await env.auth.logout();
      await expectLater(
        vm.updateRating(ratingId: 1, score: 3),
        _savesWith('로그인이 필요해요.'),
      );
      await expectLater(vm.deleteRating(1), _savesWith('로그인이 필요해요.'));
      expect(env.ratingApi.updatedCalls, isEmpty);
      expect(env.ratingApi.deletedIds, isEmpty);
    });

    test('수정 중 화면이 사라져도 예외 없이 끝난다', () async {
      // tearDown이 공용 vm을 dispose하므로, 이 테스트는 따로 만든 vm을 먼저 닫는다.
      final leaving = MyRatingsViewModel(
        env.ratingApi,
        env.tmdb,
        env.auth,
        env.session,
      );
      env.ratingApi.writeGate = Completer<void>();
      final pending = leaving.updateRating(ratingId: 1, score: 3);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      leaving.dispose();
      env.ratingApi.writeGate!.complete();
      await pending; // dispose 뒤 notifyListeners가 불리면 예외가 난다
    });
  });

  group('MyRatingsViewModel 편집 · 다중 선택 삭제 (Challenge)', () {
    late MyRatingsViewModel vm;

    setUp(() async {
      await env.signIn();
      env.tmdb.moviesById
        ..[27205] = movie(27205)
        ..[680] = movie(680);
      env.seed([
        memberRating(4, 155, comment: null),
        memberRating(3, 550),
        memberRating(2, 27205),
        memberRating(1, 680),
      ]);
      vm = MyRatingsViewModel(env.ratingApi, env.tmdb, env.auth, env.session);
      await vm.loadMovies();
    });

    tearDown(() => vm.dispose());

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
      expect(env.ratingApi.deletedIds, [4, 2]); // 선택 순서대로
      expect(vm.ratings.map((e) => e.rating.ratingId), [3, 1]);
      expect(vm.selectedRatingIds, isEmpty);
      expect(vm.isEditing, isFalse);
      expect(vm.isDeletingSelected, isFalse);
      expect(seenDeleting.first, isTrue); // 시작하자마자 로딩 오버레이가 켜진다
      expect(seenDeleting.last, isFalse);
    });

    test('일부만 실패하면 성공한 항목만 사라지고 실패한 항목은 선택이 유지된다', () async {
      env.ratingApi.failDeleteIds.add(2);
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
      env.ratingApi.failDeleteIds.clear();
      final retry = await vm.deleteSelectedRatings();
      expect(retry, (deleted: 1, failed: 0));
      expect(vm.ratings.map((e) => e.rating.ratingId), [3]);
      expect(vm.isEditing, isFalse);
    });

    test('삭제 중 토큰이 만료(401)되면 세션을 정리하고 나머지는 시도하지 않는다', () async {
      env.ratingApi.failures['delete'] = apiFailure(
        '/ratings/4',
        401,
        code: 'AUTH401_3',
        message: '토큰이 만료되었습니다.',
      );
      vm.startEditing();
      vm
        ..toggleSelection(4)
        ..toggleSelection(3)
        ..toggleSelection(2);

      final result = await vm.deleteSelectedRatings();

      expect(result, (deleted: 0, failed: 3));
      expect(env.ratingApi.deletedIds, [4], reason: '첫 401 뒤에는 더 보내지 않는다');
      expect(env.auth.status, AuthStatus.signedOut);
      expect(env.auth.sessionExpired, isTrue);
    });

    test('삭제 중에는 다시 호출해도 무시하고, 편집 모드를 바꾸거나 선택을 바꿀 수 없다', () async {
      vm.startEditing();
      vm.toggleSelection(4);
      env.ratingApi.writeGate = Completer<void>();
      final running = vm.deleteSelectedRatings();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(vm.isDeletingSelected, isTrue);

      expect(await vm.deleteSelectedRatings(), (deleted: 0, failed: 0));
      vm.cancelEditing();
      vm.toggleSelection(3);
      expect(vm.isEditing, isTrue);
      expect(vm.selectedRatingIds, {4});
      expect(env.ratingApi.deletedIds, hasLength(1));

      env.ratingApi.writeGate!.complete();
      await running;
      expect(vm.isDeletingSelected, isFalse);
    });

    test('선택이 없으면 아무 요청도 보내지 않는다', () async {
      vm.startEditing();
      expect(await vm.deleteSelectedRatings(), (deleted: 0, failed: 0));
      expect(env.ratingApi.deletedIds, isEmpty);
    });

    test('세션에서 사라진 평점(다른 화면에서 삭제)은 선택 목록에서도 빠진다', () {
      vm.startEditing();
      vm
        ..toggleSelection(3)
        ..toggleSelection(1);
      env.session.remove(3, version: env.auth.sessionVersion);
      expect(vm.selectedRatingIds, {1});
    });
  });
}
