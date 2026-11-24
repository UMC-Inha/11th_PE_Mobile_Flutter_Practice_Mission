import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';

import 'support.dart';

/// 영화 id가 page마다 겹치지 않는 Discover 응답을 만든다(page p의 id는 p*100 + 1~perPage).
TmdbMoviePageDto _page(int page, {int perPage = 3, int totalPages = 5}) =>
    TmdbMoviePageDto(
      page: page,
      results: List.generate(perPage, (i) => movie(page * 100 + i + 1)),
      totalPages: totalPages,
      totalResults: totalPages * perPage,
    );

void main() {
  late FakeTmdbMovieService service;
  late PagedMoviesViewModel vm;

  setUp(() {
    service = FakeTmdbMovieService(delay: Duration.zero, perPage: 3)
      ..discoverPage = (page, genreIds) => _page(page);
    vm = PagedMoviesViewModel(service);
  });

  tearDown(() => vm.dispose());

  group('첫 page와 더 보기', () {
    test('첫 page 성공: 목록을 교체하고 nextPage는 2가 된다', () async {
      expect(vm.phase, LoadPhase.idle);
      final loading = vm.loadInitial();
      expect(vm.phase, LoadPhase.loading);
      await loading;
      expect(vm.phase, LoadPhase.ready);
      expect(vm.movies.map((m) => m.id), [101, 102, 103]);
      expect(vm.nextPage, 2);
      expect(vm.totalPages, 5);
      expect(vm.hasMore, isTrue);
      expect(service.discoverCalls.single.page, 1);
    });

    test('첫 page 결과가 비면 Error가 아니라 empty다', () async {
      service.discoverPage = (page, _) =>
          const TmdbMoviePageDto(
            page: 1,
            results: [],
            totalPages: 0,
            totalResults: 0,
          );
      await vm.loadInitial();
      expect(vm.phase, LoadPhase.empty);
      expect(vm.hasMore, isFalse);
      expect(vm.errorMessage, isNull);
    });

    test('더 보기: 다음 page를 이어 붙이고 nextPage를 올린다(첫 page를 다시 받지 않는다)', () async {
      await vm.loadInitial();
      await vm.loadNextPage();
      expect(vm.movies.map((m) => m.id), [101, 102, 103, 201, 202, 203]);
      expect(vm.nextPage, 3);
      expect(service.discoverCalls.map((c) => c.page), [1, 2]);
      expect(vm.isLoadingMore, isFalse);
      expect(vm.phase, LoadPhase.ready, reason: '추가 로딩은 첫 로딩 상태와 다르다');
    });

    test('추가 로딩 중에는 기존 목록을 그대로 두고 isLoadingMore만 켠다', () async {
      await vm.loadInitial();
      service.gate = Completer<void>();
      final more = vm.loadNextPage();
      expect(vm.isLoadingMore, isTrue);
      expect(vm.phase, LoadPhase.ready);
      expect(vm.movies, hasLength(3));
      service.gate!.complete();
      await more;
      expect(vm.isLoadingMore, isFalse);
      expect(vm.movies, hasLength(6));
    });

    test('같은 movieId는 append할 때 한 번만 둔다(순서는 먼저 받은 쪽 그대로)', () async {
      service.discoverPage = (page, _) => TmdbMoviePageDto(
        page: page,
        // page 2가 page 1의 102·103을 다시 내려준다.
        results: page == 1
            ? [movie(101), movie(102), movie(103)]
            : [movie(102), movie(103), movie(201)],
        totalPages: 5,
        totalResults: 15,
      );
      await vm.loadInitial();
      await vm.loadNextPage();
      expect(vm.movies.map((m) => m.id), [101, 102, 103, 201]);
    });

    test('다음 page가 실패하면 목록과 nextPage를 그대로 두고, 같은 page를 다시 요청한다', () async {
      await vm.loadInitial();
      service.failDiscover = true;
      await vm.loadNextPage();
      expect(vm.loadMoreError, isNotNull);
      expect(vm.movies, hasLength(3), reason: '기존 목록은 지우지 않는다');
      expect(vm.nextPage, 2, reason: '실패하면 page가 건너뛰어지지 않는다');
      expect(vm.isLoadingMore, isFalse);
      expect(vm.phase, LoadPhase.ready);

      service.failDiscover = false;
      await vm.loadNextPage();
      expect(service.discoverCalls.map((c) => c.page), [1, 2, 2]);
      expect(vm.movies.map((m) => m.id), [101, 102, 103, 201, 202, 203]);
      expect(vm.loadMoreError, isNull);
      expect(vm.nextPage, 3);
    });

    test('다음 page를 받는 중에 또 부르면 요청을 하나만 보낸다', () async {
      await vm.loadInitial();
      service.gate = Completer<void>();
      final first = vm.loadNextPage();
      final second = vm.loadNextPage();
      final third = vm.loadNextPage();
      service.gate!.complete();
      await Future.wait([first, second, third]);
      expect(service.discoverCalls.map((c) => c.page), [1, 2]);
      expect(vm.movies, hasLength(6));
    });

    test('첫 page를 받는 중이나 목록이 없을 때는 더 보기를 요청하지 않는다', () async {
      await vm.loadNextPage(); // idle
      expect(service.discoverCalls, isEmpty);
      service.gate = Completer<void>();
      final first = vm.loadInitial();
      await vm.loadNextPage(); // loading
      service.gate!.complete();
      await first;
      expect(service.discoverCalls.map((c) => c.page), [1]);
    });

    test('마지막 page를 받으면 hasMore가 꺼지고 더 요청하지 않는다', () async {
      service.discoverPage = (page, _) => _page(page, totalPages: 2);
      await vm.loadInitial();
      expect(vm.hasMore, isTrue);
      await vm.loadNextPage();
      expect(vm.nextPage, 3);
      expect(vm.hasMore, isFalse);
      await vm.loadNextPage();
      expect(service.discoverCalls.map((c) => c.page), [1, 2]);
    });

    test('total_pages가 500보다 커도 501은 요청하지 않는다', () async {
      service
        ..perPage = 1
        ..discoverPage = (page, _) => _page(page, perPage: 1, totalPages: 9999);
      await vm.loadInitial();
      expect(vm.totalPages, PagedMoviesViewModel.maxTmdbPage);
      while (vm.hasMore) {
        await vm.loadNextPage();
      }
      expect(service.discoverCalls.last.page, 500);
      expect(service.discoverCalls.any((c) => c.page > 500), isFalse);
      expect(service.discoverCalls, hasLength(500));
      expect(vm.nextPage, 501);
    });

    test('요청한 page와 다른 page 응답은 이어 붙이지 않고 실패로 본다', () async {
      await vm.loadInitial();
      service.discoverPage = (page, _) => _page(1); // 2를 요청했는데 1을 준다
      await vm.loadNextPage();
      expect(vm.loadMoreError, isNotNull);
      expect(vm.movies, hasLength(3));
      expect(vm.nextPage, 2);
    });

    test('첫 page 실패는 Error 상태와 안내, reload로 같은 조건을 다시 받는다', () async {
      service.failDiscover = true;
      await vm.loadInitial(genreIds: const [28]);
      expect(vm.phase, LoadPhase.error);
      expect(vm.errorMessage, contains('네트워크'));
      expect(vm.movies, isEmpty);

      service.failDiscover = false;
      await vm.reload();
      expect(vm.phase, LoadPhase.ready);
      expect(service.discoverCalls.last.genreIds, [28]);
      expect(service.discoverCalls.last.page, 1);
    });
  });

  group('조건이 바뀔 때', () {
    test('장르·새로고침이 바뀌면 목록·page·추가 로딩 상태·오류를 모두 초기화한다', () async {
      await vm.loadInitial();
      await vm.loadNextPage();
      service.failDiscover = true;
      await vm.loadNextPage();
      expect(vm.loadMoreError, isNotNull);
      expect(vm.nextPage, 3);

      // 오류가 남은 채로 새 조건의 첫 page를 요청한다(응답은 붙잡아 중간 상태를 본다).
      service
        ..failDiscover = false
        ..gate = Completer<void>();
      final reloading = vm.loadInitial(genreIds: const [12]);
      expect(vm.phase, LoadPhase.loading);
      expect(vm.movies, isEmpty);
      expect(vm.nextPage, 1);
      expect(vm.totalPages, 1);
      expect(vm.isLoadingMore, isFalse);
      expect(vm.loadMoreError, isNull);
      service.gate!.complete();
      await reloading;
      expect(vm.movies.map((m) => m.id), [101, 102, 103]);
      expect(vm.nextPage, 2);
    });

    test('추가 로딩 중에 조건이 바뀌면 spinner가 남지 않는다', () async {
      await vm.loadInitial();
      final held = Completer<void>();
      service.beforeResponse = (call) async {
        if (call.page == 2) await held.future;
      };
      final more = vm.loadNextPage();
      expect(vm.isLoadingMore, isTrue);

      await vm.loadInitial(genreIds: const [12]);
      expect(vm.isLoadingMore, isFalse);
      held.complete();
      await more;
      expect(vm.isLoadingMore, isFalse);
    });

    test('느린 이전 조건의 첫 page 응답이 새 결과를 덮지 않는다(응답 순서가 요청과 반대)', () async {
      final slow = Completer<void>();
      service.discoverPage = (page, genreIds) => TmdbMoviePageDto(
        page: page,
        results: [movie(genreIds!.first * 10 + page)],
        totalPages: 3,
        totalResults: 3,
      );
      service.beforeResponse = (call) async {
        if (call.genreIds?.first == 28) await slow.future;
      };

      final first = vm.loadInitial(genreIds: const [28]); // 느린 요청
      await vm.loadInitial(genreIds: const [12]); // 나중에 보냈지만 먼저 끝난다
      expect(vm.movies.map((m) => m.id), [121]);

      slow.complete(); // 이전 조건의 응답이 이제야 도착
      await first;
      expect(vm.movies.map((m) => m.id), [121]);
      expect(vm.phase, LoadPhase.ready);
      expect(vm.nextPage, 2);
    });

    test('느린 이전 조건의 오류도 새 결과를 오류 화면으로 바꾸지 않는다', () async {
      final slow = Completer<void>();
      service.beforeResponse = (call) async {
        if (call.genreIds?.first == 28) {
          await slow.future;
          throw FakeTmdbMovieService.failure('/discover/movie');
        }
      };
      final first = vm.loadInitial(genreIds: const [28]);
      await vm.loadInitial(genreIds: const [12]);
      slow.complete();
      await first;
      expect(vm.phase, LoadPhase.ready);
      expect(vm.errorMessage, isNull);
      expect(vm.movies, isNotEmpty);
    });

    test('이전 조건의 느린 "더 보기" 응답은 새 목록에 붙지 않는다', () async {
      await vm.loadInitial(genreIds: const [28]);
      final slow = Completer<void>();
      service.beforeResponse = (call) async {
        if (call.page == 2 && call.genreIds?.first == 28) await slow.future;
      };
      final more = vm.loadNextPage(); // 장르 28의 page 2
      await vm.loadInitial(genreIds: const [12]);
      final idsAfterChange = vm.movies.map((m) => m.id).toList();

      slow.complete();
      await more;
      expect(vm.movies.map((m) => m.id), idsAfterChange);
      expect(vm.nextPage, 2, reason: '이전 조건의 응답이 page를 올리지 않는다');
      expect(vm.isLoadingMore, isFalse);
    });

    test('dispose 뒤에 도착한 응답은 무시하고 예외도 없다', () async {
      final local = PagedMoviesViewModel(service); // tearDown이 vm을 또 dispose하므로 따로 만든다
      service.gate = Completer<void>();
      final loading = local.loadInitial();
      local.dispose();
      service.gate!.complete();
      await loading;
      await local.loadNextPage(); // dispose된 뒤 호출도 조용히 무시
      expect(local.isDisposed, isTrue);
    });
  });

  group('검색', () {
    test('검색어는 trim해서 Search API로 보내고 page 1부터 시작한다', () async {
      await vm.search('  어벤져스  ');
      expect(service.searchCalls.single, (page: 1, query: '어벤져스'));
      expect(service.discoverCalls, isEmpty);
      expect(vm.query, '어벤져스');
      expect(vm.phase, LoadPhase.ready);
    });

    test('빈 검색어(공백만 포함)는 서버로 보내지 않고 입력 안내만 남긴다', () async {
      await vm.search('');
      await vm.search('   ');
      expect(service.searchCalls, isEmpty);
      expect(service.discoverCalls, isEmpty, reason: '목록 API로 새어 나가지도 않는다');
      expect(vm.phase, LoadPhase.idle);
      expect(vm.inputHint, isNotNull);
    });

    test('빈 검색어를 제출해도 이미 받은 검색 결과는 지우지 않는다', () async {
      await vm.search('어벤져스');
      final before = vm.movies.map((m) => m.id).toList();
      await vm.search('  ');
      expect(vm.phase, LoadPhase.ready);
      expect(vm.movies.map((m) => m.id), before);
      expect(service.searchCalls, hasLength(1));
    });

    test('검색 결과도 더 보기로 같은 검색어의 다음 page를 이어 받는다', () async {
      service.searchPage = (page, query) => TmdbMoviePageDto(
        page: page,
        results: [movie(page * 10 + 1, title: '$query $page')],
        totalPages: 3,
        totalResults: 3,
      );
      await vm.search('매트릭스');
      await vm.loadNextPage();
      expect(service.searchCalls.map((c) => (c.page, c.query)), [
        (1, '매트릭스'),
        (2, '매트릭스'),
      ]);
      expect(vm.movies.map((m) => m.title), ['매트릭스 1', '매트릭스 2']);
    });

    test('결과가 없으면 empty, 새 검색어를 제출하면 이전 결과를 비우고 page 1부터 받는다', () async {
      service.searchPage = (page, query) => query == '없는영화'
          ? const TmdbMoviePageDto(
              page: 1,
              results: [],
              totalPages: 0,
              totalResults: 0,
            )
          : _page(page);
      await vm.search('매트릭스');
      await vm.loadNextPage();
      expect(vm.movies, hasLength(6));

      await vm.search('없는영화');
      expect(vm.phase, LoadPhase.empty);
      expect(vm.movies, isEmpty);
      expect(vm.hasMore, isFalse, reason: '결과가 없으면 더 보기도 없다');
      expect(vm.query, '없는영화');
      expect(service.searchCalls.last, (page: 1, query: '없는영화'));
    });

    test('이전 검색어의 느린 응답이 새 검색어의 결과에 섞이지 않는다', () async {
      final slow = Completer<void>();
      service.searchPage = (page, query) => TmdbMoviePageDto(
        page: page,
        results: [movie(query.length * 100 + page, title: query)],
        totalPages: 2,
        totalResults: 2,
      );
      service.beforeResponse = (call) async {
        if (call.query == '어벤') await slow.future;
      };
      final first = vm.search('어벤'); // 느림
      await vm.search('어벤져스'); // 나중에 보냈지만 먼저 끝남
      expect(vm.movies.map((m) => m.title), ['어벤져스']);

      slow.complete();
      await first;
      expect(vm.movies.map((m) => m.title), ['어벤져스']);
      expect(vm.query, '어벤져스');
    });

    test('검색 실패는 검색용 문구의 Error이고, reload는 마지막 검색어로 다시 요청한다', () async {
      service.failSearch = true;
      await vm.search('매트릭스');
      expect(vm.phase, LoadPhase.error);
      service.failSearch = false;
      await vm.reload();
      expect(vm.phase, LoadPhase.ready);
      expect(service.searchCalls.last, (page: 1, query: '매트릭스'));
    });
  });
}
