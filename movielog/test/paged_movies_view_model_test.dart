import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';

/// 요청마다 응답 시점을 테스트가 직접 정하는 TMDB Service입니다.
class _ControlledTmdb extends TmdbMovieService {
  _ControlledTmdb() : super(Dio());

  final pending = <_Request>[];

  Future<TmdbMoviePageDto> _enqueue(int page, int? genreId, String? query) {
    final request = _Request(page, genreId, query);
    pending.add(request);
    return request.completer.future;
  }

  @override
  Future<TmdbMoviePageDto> discoverMovies({required int page, int? genreId}) =>
      _enqueue(page, genreId, null);

  @override
  Future<TmdbMoviePageDto> searchMovies({
    required int page,
    required String query,
  }) => _enqueue(page, null, query);
}

class _Request {
  _Request(this.page, this.genreId, this.query);
  final int page;
  final int? genreId;
  final String? query;
  final completer = Completer<TmdbMoviePageDto>();

  void succeed(List<int> ids, {int totalPages = 3}) {
    completer.complete(
      TmdbMoviePageDto(
        page: page,
        results: [for (final id in ids) _movie(id)],
        totalPages: totalPages,
        totalResults: ids.length * totalPages,
      ),
    );
  }

  void fail() => completer.completeError(
    DioException(
      requestOptions: RequestOptions(path: '/discover/movie'),
      type: DioExceptionType.connectionError,
    ),
  );
}

TmdbMovieDto _movie(int id) => TmdbMovieDto(
  id: id,
  title: '영화 $id',
  overview: '',
  posterPath: null,
  backdropPath: null,
  releaseDate: null,
  genreIds: const [],
  voteAverage: 0,
  popularity: 0,
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('첫 page 후 더 보기로 다음 page를 이어 붙이고 중복 id는 제외한다', () async {
    final tmdb = _ControlledTmdb();
    final vm = PagedMoviesViewModel(tmdbApi: tmdb);

    final first = vm.loadInitial();
    expect(vm.phase, LoadPhase.loading);
    tmdb.pending.last.succeed([1, 2, 3]);
    await first;
    expect(vm.phase, LoadPhase.ready);
    expect(vm.nextPage, 2);

    final more = vm.loadNextPage();
    expect(vm.isLoadingMore, isTrue);
    expect(vm.movies, hasLength(3)); // 기존 카드는 유지
    expect(tmdb.pending.last.page, 2);
    tmdb.pending.last.succeed([3, 4, 5]);
    await more;
    expect(vm.movies.map((m) => m.id), [1, 2, 3, 4, 5]);
    expect(vm.nextPage, 3);
    expect(vm.isLoadingMore, isFalse);
  });

  test('다음 page 실패 후 재시도하면 같은 page를 다시 요청한다', () async {
    final tmdb = _ControlledTmdb();
    final vm = PagedMoviesViewModel(tmdbApi: tmdb);
    final first = vm.loadInitial();
    tmdb.pending.last.succeed([1, 2]);
    await first;

    final failed = vm.loadNextPage();
    tmdb.pending.last.fail();
    await failed;
    expect(vm.loadMoreError, isNotNull);
    expect(vm.nextPage, 2);
    expect(vm.movies, hasLength(2));

    final retry = vm.loadNextPage();
    expect(tmdb.pending.last.page, 2);
    tmdb.pending.last.succeed([3]);
    await retry;
    expect(vm.loadMoreError, isNull);
    expect(vm.nextPage, 3);
  });

  test('마지막 page면 hasMore가 false이고 더 요청하지 않는다', () async {
    final tmdb = _ControlledTmdb();
    final vm = PagedMoviesViewModel(tmdbApi: tmdb);
    final first = vm.loadInitial();
    tmdb.pending.last.succeed([1], totalPages: 1);
    await first;
    expect(vm.hasMore, isFalse);
    await vm.loadNextPage();
    expect(tmdb.pending, hasLength(1));
  });

  test('total_pages가 500보다 커도 500 page까지만 요청한다', () async {
    final tmdb = _ControlledTmdb();
    final vm = PagedMoviesViewModel(tmdbApi: tmdb);
    final first = vm.loadInitial();
    tmdb.pending.last.succeed([1], totalPages: 40000);
    await first;
    expect(vm.totalPages, 500);
  });

  test('장르를 바꾸면 이전 장르의 늦은 응답은 무시한다', () async {
    final tmdb = _ControlledTmdb();
    final vm = PagedMoviesViewModel(tmdbApi: tmdb);
    final first = vm.loadInitial();
    tmdb.pending.last.succeed([1, 2]);
    await first;

    // 이전 장르에서 더 보기 요청 중 장르 변경
    final more = vm.loadNextPage();
    final oldMore = tmdb.pending.last;
    final action = vm.loadInitial(genreId: 28);
    expect(vm.movies, isEmpty);
    expect(vm.isLoadingMore, isFalse);
    final actionRequest = tmdb.pending.last;
    expect(actionRequest.genreId, 28);

    actionRequest.succeed([100, 101]);
    await action;
    oldMore.succeed([3, 4]); // 늦게 도착한 이전 장르 응답
    await more;
    await _settle();
    expect(vm.movies.map((m) => m.id), [100, 101]);
    expect(vm.nextPage, 2);
  });

  test('검색어를 빠르게 바꾸면 이전 검색어 결과가 새 결과를 덮어쓰지 않는다', () async {
    final tmdb = _ControlledTmdb();
    final vm = PagedMoviesViewModel(tmdbApi: tmdb);
    final oldSearch = vm.loadInitial(query: '어벤');
    final oldRequest = tmdb.pending.last;
    final newSearch = vm.loadInitial(query: ' 어벤져스 ');
    final newRequest = tmdb.pending.last;
    expect(newRequest.query, '어벤져스');

    newRequest.succeed([7]);
    await newSearch;
    oldRequest.succeed([1, 2, 3]);
    await oldSearch;
    expect(vm.movies.map((m) => m.id), [7]);
    expect(vm.query, '어벤져스');
  });

  test('결과가 없으면 empty, 첫 page 실패면 error이다', () async {
    final tmdb = _ControlledTmdb();
    final vm = PagedMoviesViewModel(tmdbApi: tmdb);
    final empty = vm.loadInitial(query: '없는영화');
    tmdb.pending.last.succeed([], totalPages: 0);
    await empty;
    expect(vm.phase, LoadPhase.empty);

    final error = vm.loadInitial(query: '오류');
    tmdb.pending.last.fail();
    await error;
    expect(vm.phase, LoadPhase.error);
    expect(vm.errorMessage, '검색 결과를 불러오지 못했습니다.');
  });

  test('화면이 사라진 뒤 도착한 응답은 반영하지 않는다', () async {
    final tmdb = _ControlledTmdb();
    final vm = PagedMoviesViewModel(tmdbApi: tmdb);
    final first = vm.loadInitial();
    vm.dispose();
    tmdb.pending.last.succeed([1]);
    await first; // dispose 후 notifyListeners 오류가 나지 않아야 합니다.
    expect(vm.movies, isEmpty);
  });
}
