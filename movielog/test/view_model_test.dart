import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/storage/genre_preference.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

import 'support.dart';

void expectCall(
  ({int page, List<int>? genreIds}) call,
  int page,
  List<int> genreIds,
) {
  expect(call.page, page);
  expect(call.genreIds, genreIds);
}

void main() {
  group('MovieHomeViewModel — 인기 5개', () {
    test('Popular 20개 중 앞 5개, 순서 유지', () async {
      final service = FakeTmdbMovieService(delay: Duration.zero);
      final vm = MovieHomeViewModel(service);
      await vm.loadPopular();
      expect(vm.status, MovieHomeLoadStatus.success);
      expect(vm.popularMovies.map((m) => m.id), [100, 101, 102, 103, 104]);
      expect(service.popularCalls, 1);
    });

    test('5개보다 적으면 있는 만큼만(RangeError 없음), 0개면 Empty', () async {
      final service = FakeTmdbMovieService(delay: Duration.zero)
        ..popularResults = [movie(1), movie(2), movie(3)];
      final vm = MovieHomeViewModel(service);
      await vm.loadPopular();
      expect(vm.popularMovies, hasLength(3));
      service.popularResults = [];
      await vm.loadPopular();
      expect(vm.status, MovieHomeLoadStatus.empty);
    });

    test('실패하면 Error와 안내 문구', () async {
      final service = FakeTmdbMovieService(delay: Duration.zero)
        ..failPopular = true;
      final vm = MovieHomeViewModel(service);
      await vm.loadPopular();
      expect(vm.status, MovieHomeLoadStatus.error);
      expect(vm.message, contains('네트워크'));
    });
  });

  group('MovieListViewModel — Discover 최대 30개', () {
    test('page 1부터 필요한 만큼만 요청해 30개를 만든다', () async {
      final service = FakeTmdbMovieService(delay: Duration.zero);
      final vm = MovieListViewModel(service);
      await vm.loadInitial();
      expect(vm.status, MovieListLoadStatus.success);
      expect(vm.movies, hasLength(30));
      expect(service.discoverCalls.map((c) => c.page), [1, 2]);
      expect(service.genreCalls, 1);
    });

    test('페이지 사이 중복은 TMDB id 기준으로 하나만 남긴다', () async {
      final service = FakeTmdbMovieService(delay: Duration.zero)
        // 매 페이지가 앞 페이지와 10개씩 겹친다: 1~20, 11~30, 21~40
        ..discoverPage = (page, _) => TmdbMoviePageDto(
          page: page,
          results: List.generate(20, (i) => movie((page - 1) * 10 + i + 1)),
          totalPages: 10,
          totalResults: 200,
        );
      final vm = MovieListViewModel(service);
      await vm.loadInitial();
      final ids = vm.movies.map((m) => m.id).toList();
      expect(ids, hasLength(30));
      expect(ids.toSet(), hasLength(30));
      expect(ids.first, 1);
      expect(ids.last, 30);
      // 1~20, 11~30 두 페이지면 중복 10개를 빼고 정확히 30개가 된다.
      expect(service.discoverCalls.map((c) => c.page), [1, 2]);
    });

    test('마지막 페이지에 닿으면 30개가 안 돼도 멈춘다(오류 아님)', () async {
      final service = FakeTmdbMovieService(
        delay: Duration.zero,
        perPage: 12,
        totalPages: 1,
      );
      final vm = MovieListViewModel(service);
      await vm.loadInitial();
      expect(vm.movies, hasLength(12));
      expect(vm.status, MovieListLoadStatus.success);
      expect(service.discoverCalls, hasLength(1));
    });

    test('결과가 0개면 Empty', () async {
      final service = FakeTmdbMovieService(
        delay: Duration.zero,
        perPage: 0,
        totalPages: 0,
      );
      final vm = MovieListViewModel(service);
      await vm.loadInitial();
      expect(vm.status, MovieListLoadStatus.empty);
    });

    test('장르 선택 → with_genres로 page 1부터 다시, 전체 → 장르 없이', () async {
      final service = FakeTmdbMovieService(delay: Duration.zero);
      final vm = MovieListViewModel(service);
      await vm.loadInitial();
      service.discoverCalls.clear();

      await vm.selectGenre(28);
      expectCall(service.discoverCalls.first, 1, [28]);
      expect(vm.movies.every((m) => m.genreIds.contains(28)), isTrue);
      expect(vm.selectionLabel, '액션');

      service.discoverCalls.clear();
      await vm.selectGenre(null);
      expect(service.discoverCalls.first.page, 1);
      expect(service.discoverCalls.first.genreIds, isEmpty);
    });

    test('다중 선택은 ID 목록 그대로 Service에 넘긴다', () async {
      final service = FakeTmdbMovieService(delay: Duration.zero);
      final vm = MovieListViewModel(service);
      await vm.loadInitial();
      await vm.selectGenres([28, 12]);
      expect(service.discoverCalls.last.genreIds, [28, 12]);
      expect(vm.selectionLabel, '액션, 모험');
    });

    test('Discover 요청 중에는 장르를 바꾸지 못한다', () async {
      final service = FakeTmdbMovieService(delay: Duration.zero);
      final vm = MovieListViewModel(service);
      await vm.loadInitial();
      service.gate = Completer<void>();
      final pending = vm.selectGenre(28);
      expect(vm.status, MovieListLoadStatus.loading);
      expect(vm.canChangeGenre, isFalse);
      await vm.selectGenre(12); // 무시된다
      service.gate!.complete();
      await pending;
      expect(vm.selectedGenreIds, [28]);
      expect(
        service.discoverCalls.any((c) => c.genreIds?.contains(12) ?? false),
        isFalse,
      );
    });

    test('dispose 뒤 늦게 온 응답은 무시한다', () async {
      final service = FakeTmdbMovieService(delay: Duration.zero)
        ..gate = Completer<void>();
      final vm = MovieListViewModel(service);
      final pending = vm.loadInitial();
      vm.dispose();
      service.gate!.complete();
      await pending; // notifyListeners after dispose 예외가 없어야 한다
    });

    test('새로고침: 기존 목록을 유지한 채 다시 받고, Loading 중에는 무시', () async {
      final service = FakeTmdbMovieService(delay: Duration.zero);
      final vm = MovieListViewModel(service);
      await vm.loadInitial();
      await vm.selectGenre(28);
      final before = vm.movies;
      service.discoverCalls.clear();
      service.gate = Completer<void>();

      final refreshing = vm.refresh();
      expect(vm.isRefreshing, isTrue);
      expect(vm.status, MovieListLoadStatus.success);
      expect(vm.movies, same(before));
      await vm.refresh(); // 새로고침 중 두 번째 당김은 무시
      service.gate!.complete();
      await refreshing;
      expect(vm.isRefreshing, isFalse);
      expectCall(service.discoverCalls.first, 1, [28]);
      expect(service.discoverCalls.where((c) => c.page == 1), hasLength(1));
    });

    test('최근 목록이 있으면 실패해도 비우지 않고 재시도 알림, 재시도는 같은 장르로', () async {
      final service = FakeTmdbMovieService(delay: Duration.zero);
      final vm = MovieListViewModel(service);
      await vm.loadInitial();
      await vm.selectGenres([28, 12]);
      final kept = vm.movies;

      service.failDiscover = true;
      await vm.refresh();
      expect(vm.status, MovieListLoadStatus.success);
      expect(vm.movies, same(kept));
      expect(vm.retryNoticeCount, 1);

      service.failDiscover = false;
      service.discoverCalls.clear();
      await vm.retry();
      expectCall(service.discoverCalls.first, 1, [28, 12]);
      expect(vm.movies, isNot(same(kept)));
    });

    test('장르를 바꾸다 실패 후 취소하면 선택을 화면 목록에 맞게 되돌린다', () async {
      final service = FakeTmdbMovieService(delay: Duration.zero);
      final vm = MovieListViewModel(service);
      await vm.loadInitial();
      service.failDiscover = true;
      await vm.selectGenre(18);
      expect(vm.selectedGenreIds, [18]);
      expect(vm.retryNoticeCount, 1);
      vm.cancelRetry();
      expect(vm.selectedGenreIds, isEmpty);
    });

    test('목록이 없을 때 실패하면 Error, 재시도로 Success', () async {
      final service = FakeTmdbMovieService(delay: Duration.zero)
        ..failDiscover = true;
      final vm = MovieListViewModel(service);
      await vm.loadInitial();
      expect(vm.status, MovieListLoadStatus.error);
      service.failDiscover = false;
      await vm.retry();
      expect(vm.status, MovieListLoadStatus.success);
    });

    test('저장한 장르·정렬 복원, 주소 장르가 우선, 모르는 ID는 버림', () async {
      final preferences = MemoryMoviePreferences(
        const MovieListSettings(genreIds: [18, 99999], sort: MovieSort.rating),
      );
      final service = FakeTmdbMovieService(delay: Duration.zero);
      final restored = MovieListViewModel(service, preferences: preferences);
      await restored.loadInitial();
      expect(restored.selectedGenreIds, [18]);
      expect(restored.sort, MovieSort.rating);
      expect(service.discoverCalls.first.genreIds, [18]);

      final fromUrl = MovieListViewModel(
        service,
        preferences: preferences,
        initialGenreIds: const [28],
      );
      await fromUrl.loadInitial();
      expect(fromUrl.selectedGenreIds, [28]);

      await fromUrl.selectGenres([12, 28]);
      fromUrl.setSort(MovieSort.title);
      await fromUrl.pendingSave;
      expect(preferences.settings.genreIds, [12, 28]);
      expect(preferences.settings.sort, MovieSort.title);
    });

    test('정렬은 받은 목록 안에서만 바꾸고 재요청하지 않는다', () async {
      final service = FakeTmdbMovieService(delay: Duration.zero)
        ..discoverPage = (page, _) => TmdbMoviePageDto(
          page: 1,
          results: [
            movie(1, title: '다', voteAverage: 6),
            movie(2, title: '가', voteAverage: 9),
          ],
          totalPages: 1,
          totalResults: 2,
        );
      final vm = MovieListViewModel(service);
      await vm.loadInitial();
      vm.setSort(MovieSort.title);
      expect(vm.visibleMovies.map((m) => m.title), ['가', '다']);
      vm.setSort(MovieSort.rating);
      expect(vm.visibleMovies.first.voteAverage, 9);
      expect(service.discoverCalls, hasLength(1));
    });
  });

  test('MyRatingsViewModel: 자체 백엔드 평점 + movieId로 TMDB 제목', () async {
    final tmdb = FakeTmdbMovieService(delay: Duration.zero)
      ..moviesById[550] = movie(550, title: '파이트 클럽');
    final api = FakeMovieLogApiService();
    final vm = MyRatingsViewModel(api, tmdb);
    await vm.load();
    expect(vm.status, MyRatingsLoadStatus.success);
    expect(vm.ratings.map((r) => r.ratingId), [2, 1]);
    expect(vm.moviesById[550]?.title, '파이트 클럽');
    expect(vm.moviesById.containsKey(155), isFalse); // TMDB 실패해도 목록은 유지
    expect(vm.averageScore, 4.5);
    expect(tmdb.movieCalls.toSet(), {155, 550});
  });

  test('SignUpViewModel: 중복 확인 후 입력을 바꾸면 다시 확인해야 한다', () async {
    final api = FakeMovieLogApiService();
    final vm = SignUpViewModel(api);
    await vm.checkNickname(' 수현 ');
    expect(vm.nickname.status, DuplicateCheckStatus.taken);
    expect(api.checkedNicknames.single, '수현');
    await vm.checkNickname('케빈');
    expect(vm.isNicknameConfirmed('케빈'), isTrue);
    vm.onNicknameChanged('케빈2');
    expect(vm.isNicknameConfirmed('케빈2'), isFalse);
    expect(vm.nickname.status, DuplicateCheckStatus.unchecked);

    api.fail = true;
    await vm.checkEmail('kevin@umc.com');
    expect(vm.email.status, DuplicateCheckStatus.failed);
  });
}
