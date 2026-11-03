import 'package:dio/dio.dart';

import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

/// 실제 TMDB 대신 미리 정해 둔 영화를 돌려주는 테스트용 Service입니다.
class FakeTmdbMovieService extends TmdbMovieService {
  FakeTmdbMovieService({
    this.popularIds = const [],
    this.discoverPages = const [],
    this.idsWithoutPoster = const {},
    this.popularDelay = Duration.zero,
    this.failWithParseError = false,
    this.missingMovieIds = const {},
    this.networkFailMovieIds = const {},
  }) : super(Dio());

  /// 상세 조회에서 404를 돌려줄 영화 ID입니다. (TMDB에 없는 영화)
  final Set<int> missingMovieIds;

  /// 상세 조회에서 네트워크 오류를 낼 영화 ID입니다.
  final Set<int> networkFailMovieIds;

  final detailRequests = <int>[];

  /// Popular 응답을 늦게 돌려줄 시간입니다. (응답 전에 화면을 떠나는 상황 재현)
  final Duration popularDelay;

  /// true면 응답 형식이 달라 DTO 변환에 실패한 상황처럼 TypeError를 던집니다.
  final bool failWithParseError;

  /// Popular 첫 페이지가 돌려줄 영화 ID 목록입니다.
  final List<int> popularIds;

  /// Discover가 page 번호(1부터) 순서대로 돌려줄 영화 ID 목록입니다.
  final List<List<int>> discoverPages;

  /// `poster_path`를 null로 내려줄 영화 ID입니다.
  final Set<int> idsWithoutPoster;

  int popularRequestCount = 0;
  final requestedGenreIds = <int?>[];
  final requestedPages = <int>[];

  @override
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async {
    popularRequestCount++;
    await Future<void>.delayed(popularDelay);
    if (failWithParseError) _throwParseError();
    return TmdbMoviePageDto(
      page: page,
      results: [for (final id in popularIds) movie(id)],
      totalPages: 1,
      totalResults: popularIds.length,
    );
  }

  @override
  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    int? genreId,
  }) async {
    requestedGenreIds.add(genreId);
    requestedPages.add(page);
    if (failWithParseError) _throwParseError();

    return TmdbMoviePageDto(
      page: page,
      results: [for (final id in discoverPages[page - 1]) movie(id)],
      totalPages: discoverPages.length,
      totalResults: discoverPages.fold(0, (sum, ids) => sum + ids.length),
    );
  }

  @override
  Future<List<TmdbGenreDto>> fetchGenres() async {
    return const [TmdbGenreDto(id: 28, name: '액션')];
  }

  @override
  Future<TmdbMovieDto> fetchMovieDetail(int movieId) async {
    detailRequests.add(movieId);
    final options = RequestOptions(path: '/movie/$movieId');
    if (missingMovieIds.contains(movieId)) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: options, statusCode: 404),
      );
    }
    if (networkFailMovieIds.contains(movieId)) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    return movie(movieId);
  }

  /// 숫자 자리에 문자열이 온 JSON을 변환할 때처럼 TypeError를 발생시킵니다.
  static Never _throwParseError() {
    TmdbMovieDto.fromJson({'id': 'not-a-number'});
    throw StateError('unreachable');
  }

  TmdbMovieDto movie(int id) {
    return TmdbMovieDto(
      id: id,
      title: '영화 $id',
      overview: '',
      posterPath: idsWithoutPoster.contains(id) ? null : '/poster_$id.jpg',
      backdropPath: null,
      releaseDate: '2024-01-01',
      genreIds: const [],
      voteAverage: 7.5,
      popularity: 0,
    );
  }
}
