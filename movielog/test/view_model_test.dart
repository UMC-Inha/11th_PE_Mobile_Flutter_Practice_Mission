import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/storage/genre_preference.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';

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

  group('MovieListViewModel — 첫 page만, 더 보기로 이어서', () {
    test('첫 page 하나만 요청해 그 page의 영화를 보여준다(30개를 모으지 않는다)', () async {
      final service = FakeTmdbMovieService(delay: Duration.zero);
      final vm = MovieListViewModel(service);
      await vm.loadInitial();
      expect(vm.status, MovieListLoadStatus.success);
      expect(vm.movies, hasLength(20));
      expect(service.discoverCalls.map((c) => c.page), [1]);
      expect(service.genreCalls, 1);
      expect(vm.paged.nextPage, 2);
    });

    test('더 보기: 다음 page를 아래에 이어 붙이고 같은 영화는 한 번만 둔다', () async {
      final service = FakeTmdbMovieService(delay: Duration.zero)
        // 매 page가 앞 page와 5개씩 겹친다: 1~20, 16~35
        ..discoverPage = (page, _) => TmdbMoviePageDto(
          page: page,
          results: List.generate(20, (i) => movie((page - 1) * 15 + i + 1)),
          totalPages: 10,
          totalResults: 200,
        );
      final vm = MovieListViewModel(service);
      await vm.loadInitial();
      await vm.paged.loadNextPage();
      final ids = vm.movies.map((m) => m.id).toList();
      expect(ids, hasLength(35));
      expect(ids.toSet(), hasLength(35));
      expect(ids.first, 1);
      expect(ids.last, 35);
      expect(service.discoverCalls.map((c) => c.page), [1, 2]);
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
      await vm.paged.loadNextPage(); // 2 page까지 봤다
      service.discoverCalls.clear();

      await vm.selectGenre(28);
      expectCall(service.discoverCalls.first, 1, [28]);
      expect(vm.movies, hasLength(20), reason: '이전 목록을 비우고 새 첫 page만');
      expect(vm.movies.every((m) => m.genreIds.contains(28)), isTrue);
      expect(vm.paged.nextPage, 2);
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
      // 카드에는 TMDB 첫 장르(드라마)보다 고른 장르(모험)를 먼저 보여준다.
      expect(vm.primaryGenreName(movie(9, genreIds: const [18, 12])), '모험');
      await vm.selectGenre(null);
      expect(vm.primaryGenreName(movie(9, genreIds: const [18, 12])), '드라마');
    });

    test('같은 장르를 다시 고르면 다시 요청하지 않는다', () async {
      final service = FakeTmdbMovieService(delay: Duration.zero);
      final vm = MovieListViewModel(service);
      await vm.loadInitial();
      await vm.selectGenre(28);
      service.discoverCalls.clear();
      await vm.selectGenre(28);
      expect(service.discoverCalls, isEmpty);
    });

    test('요청 중에 장르를 바꿔도 이전 장르의 느린 응답이 새 목록에 섞이지 않는다', () async {
      final service = FakeTmdbMovieService(delay: Duration.zero);
      final vm = MovieListViewModel(service);
      await vm.loadInitial();
      // 액션(28)은 응답을 붙잡고, 모험(12)은 바로 응답한다.
      final actionGate = Completer<void>();
      service.beforeResponse = (call) async {
        if (call.genreIds?.contains(28) ?? false) await actionGate.future;
      };
      final action = vm.selectGenre(28);
      expect(vm.status, MovieListLoadStatus.loading);
      expect(vm.canChangeGenre, isTrue, reason: '요청 중에도 바꿀 수 있다');
      await vm.selectGenre(12);
      expect(vm.movies.every((m) => m.genreIds.contains(12)), isTrue);

      actionGate.complete(); // 이전 장르의 응답이 뒤늦게 도착한다
      await action;
      expect(vm.selectedGenreIds, [12]);
      expect(vm.movies.every((m) => m.genreIds.contains(12)), isTrue);
      expect(vm.movies.any((m) => m.genreIds.contains(28)), isFalse);
      expect(vm.status, MovieListLoadStatus.success);
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

    test('새로고침: 지금 장르 그대로 page 1부터 다시 받는다', () async {
      final service = FakeTmdbMovieService(delay: Duration.zero);
      final vm = MovieListViewModel(service);
      await vm.loadInitial();
      await vm.selectGenre(28);
      await vm.paged.loadNextPage();
      service.discoverCalls.clear();

      await vm.refresh();
      expectCall(service.discoverCalls.single, 1, [28]);
      expect(vm.movies, hasLength(20));
      expect(vm.paged.nextPage, 2);
    });

    test('첫 page가 실패하면 Error와 안내 문구, 다시 시도로 Success', () async {
      final service = FakeTmdbMovieService(delay: Duration.zero)
        ..failDiscover = true;
      final vm = MovieListViewModel(service);
      await vm.loadInitial();
      expect(vm.status, MovieListLoadStatus.error);
      expect(vm.message, contains('네트워크'));
      service.failDiscover = false;
      await vm.refresh();
      expect(vm.status, MovieListLoadStatus.success);
      expect(vm.message, isNull);
    });

    test('장르 목록 조회가 실패하면 Error이고 다시 시도하면 장르부터 다시 받는다', () async {
      final service = FakeTmdbMovieService(delay: Duration.zero)..genres = [];
      // 장르 조회 실패를 흉내 내려고 gate 대신 예외를 던지는 Service를 쓴다.
      final failing = _GenreFailingService(service);
      final vm = MovieListViewModel(failing);
      await vm.loadInitial();
      expect(vm.status, MovieListLoadStatus.error);
      expect(vm.canChangeGenre, isFalse);
      expect(service.discoverCalls, isEmpty);
      failing.fail = false;
      service.genres = testGenres;
      await vm.refresh();
      expect(vm.status, MovieListLoadStatus.success);
      expect(vm.genres, isNotEmpty);
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
}

/// 장르 목록 조회만 실패하는 Service(나머지는 감싼 Service에 맡긴다).
class _GenreFailingService extends FakeTmdbMovieService {
  _GenreFailingService(FakeTmdbMovieService inner)
    : _inner = inner,
      super(delay: Duration.zero);

  final FakeTmdbMovieService _inner;
  bool fail = true;

  @override
  Future<List<TmdbGenreDto>> fetchGenres() async {
    if (fail) throw FakeTmdbMovieService.failure('/genre/movie/list');
    return _inner.fetchGenres();
  }

  @override
  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    List<int>? genreIds,
    CancelToken? cancelToken,
  }) => _inner.discoverMovies(
    page: page,
    genreIds: genreIds,
    cancelToken: cancelToken,
  );
}
