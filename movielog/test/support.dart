import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/core/storage/genre_preference.dart';
import 'package:movielog/data/models/movielog_dtos.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/data/services/movielog_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

class MemoryMoviePreferences implements MoviePreferences {
  MemoryMoviePreferences([this.settings = const MovieListSettings()]);
  MovieListSettings settings;
  int writes = 0;
  @override
  Future<MovieListSettings> read() async => settings;
  @override
  Future<void> save(MovieListSettings value) async {
    settings = value;
    writes++;
  }
}

TmdbMovieDto movie(
  int id, {
  String? title,
  String? posterPath = '/poster.jpg',
  List<int> genreIds = const [28],
  double voteAverage = 7.5,
  String? releaseDate = '2025-05-01',
  String overview = '줄거리',
}) => TmdbMovieDto(
  id: id,
  title: title ?? '영화 $id',
  overview: overview,
  posterPath: posterPath,
  backdropPath: null,
  releaseDate: releaseDate,
  genreIds: genreIds,
  voteAverage: voteAverage,
  popularity: 100.0 - id,
);

const testGenres = [
  TmdbGenreDto(id: 28, name: '액션'),
  TmdbGenreDto(id: 12, name: '모험'),
  TmdbGenreDto(id: 18, name: '드라마'),
];

/// TMDB 서버 대신 쓰는 가짜 Service. 어떤 page·장르로 불렸는지 기록한다.
class FakeTmdbMovieService implements TmdbMovieService {
  FakeTmdbMovieService({
    this.genres = testGenres,
    this.perPage = 20,
    this.totalPages = 5,
    this.delay = const Duration(milliseconds: 300),
  });

  List<TmdbGenreDto> genres;
  int perPage;
  int totalPages;
  Duration delay;

  /// 이 함수가 있으면 Discover 결과를 대신 만든다.
  TmdbMoviePageDto Function(int page, List<int>? genreIds)? discoverPage;

  /// true면 다음 요청부터 실패한다.
  bool failDiscover = false;
  bool failPopular = false;
  List<TmdbMovieDto>? popularResults;
  final moviesById = <int, TmdbMovieDto>{};

  /// 값이 있으면 응답을 이 Future가 끝날 때까지 붙잡는다.
  Completer<void>? gate;

  final discoverCalls = <({int page, List<int>? genreIds})>[];
  int popularCalls = 0;
  int genreCalls = 0;
  final movieCalls = <int>[];

  Future<void> _wait() async {
    if (gate != null) await gate!.future;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  static DioException failure(String path) => DioException(
    requestOptions: RequestOptions(path: path),
    type: DioExceptionType.connectionError,
    message: 'network down',
  );

  @override
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async {
    popularCalls++;
    await _wait();
    if (failPopular) throw failure('/movie/popular');
    final results = popularResults ?? List.generate(20, (i) => movie(100 + i));
    return TmdbMoviePageDto(
      page: 1,
      results: results,
      totalPages: 1,
      totalResults: results.length,
    );
  }

  @override
  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    List<int>? genreIds,
    CancelToken? cancelToken,
  }) async {
    discoverCalls.add((page: page, genreIds: genreIds));
    await _wait();
    if (failDiscover) throw failure('/discover/movie');
    final custom = discoverPage;
    if (custom != null) return custom(page, genreIds);
    return discoverPageFor(page, genreIds);
  }

  /// 기본 Discover 응답. 장르를 고르면 id가 (첫 장르 × 1000 + 순번)이 되어 목록이 달라진다.
  TmdbMoviePageDto discoverPageFor(
    int page,
    List<int>? genreIds, {
    int offset = 0,
    String? posterPath = '/poster.jpg',
  }) {
    final hasGenre = genreIds?.isNotEmpty ?? false;
    final base = offset + (hasGenre ? genreIds!.first * 1000 : 0);
    return TmdbMoviePageDto(
      page: page,
      results: List.generate(
        perPage,
        (i) => movie(
          base + (page - 1) * perPage + i + 1,
          posterPath: posterPath,
          genreIds: hasGenre ? genreIds! : const [28],
        ),
      ),
      totalPages: totalPages,
      totalResults: totalPages * perPage,
    );
  }

  @override
  Future<List<TmdbGenreDto>> fetchGenres() async {
    genreCalls++;
    await _wait();
    return genres;
  }

  @override
  Future<TmdbMovieDto> fetchMovie(int movieId) async {
    movieCalls.add(movieId);
    await _wait();
    final found = moviesById[movieId];
    if (found == null) throw failure('/movie/$movieId');
    return found;
  }
}

/// 자체 백엔드 대신 쓰는 가짜 Service. 시드 데이터(수현, noco@umc.com)와 같은 답을 한다.
class FakeMovieLogApiService implements MovieLogApiService {
  FakeMovieLogApiService({
    this.takenNicknames = const {'수현', '민서'},
    this.takenEmails = const {'noco@umc.com', 'minseo@umc.com'},
    List<MemberRatingDto>? ratings,
  }) : ratings = ratings ?? seedRatings;

  final Set<String> takenNicknames;
  final Set<String> takenEmails;
  List<MemberRatingDto> ratings;
  bool fail = false;
  final checkedNicknames = <String>[];
  final checkedEmails = <String>[];

  static final seedRatings = [
    MemberRatingDto(
      ratingId: 2,
      movieId: 155,
      score: 4,
      comment: '다시 봐도 명작',
      createdAt: DateTime.utc(2026, 10, 28, 13, 46),
      updatedAt: DateTime.utc(2026, 10, 28, 13, 46),
    ),
    MemberRatingDto(
      ratingId: 1,
      movieId: 550,
      score: 5,
      comment: '최고의 영화!',
      createdAt: DateTime.utc(2026, 10, 28, 13, 46),
      updatedAt: DateTime.utc(2026, 10, 28, 13, 46),
    ),
  ];

  @override
  Future<AvailabilityDto> checkNickname(String nickname) async {
    checkedNicknames.add(nickname);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (fail) throw FakeTmdbMovieService.failure('/members/nickname');
    return AvailabilityDto(available: !takenNicknames.contains(nickname));
  }

  @override
  Future<AvailabilityDto> checkEmail(String email) async {
    checkedEmails.add(email);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (fail) throw FakeTmdbMovieService.failure('/members/email');
    return AvailabilityDto(available: !takenEmails.contains(email));
  }

  @override
  Future<List<MemberRatingDto>> fetchMemberRatings(int memberId) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (fail) throw FakeTmdbMovieService.failure('/members/$memberId/ratings');
    return ratings;
  }
}
