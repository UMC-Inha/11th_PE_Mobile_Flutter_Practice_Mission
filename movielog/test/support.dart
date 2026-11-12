import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/storage/genre_preference.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/movielog_dtos.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/data/services/movielog_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

/// 위젯이 그려지고 가짜 Service의 지연까지 끝나길 기다린다. (로딩 인디케이터가 계속 도는
/// 화면에서는 pumpAndSettle이 끝나지 않으므로 쓰지 않는다.)
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

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

/// 자체 백엔드 평점 한 줄. comment를 null로 주면 후기 없는 평점이 된다.
MemberRatingDto memberRating(
  int ratingId,
  int movieId, {
  int score = 4,
  String? comment = '후기',
}) => MemberRatingDto(
  ratingId: ratingId,
  movieId: movieId,
  score: score,
  comment: comment,
  createdAt: DateTime.utc(2026, 10, 28),
  updatedAt: DateTime.utc(2026, 10, 28),
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

  /// TMDB가 404를 주는 영화 ID. [findMovieById]는 이 ID에 null을 돌려준다.
  final notFoundMovieIds = <int>{};

  @override
  Future<TmdbMovieDto?> findMovieById(int movieId) async {
    movieCalls.add(movieId);
    await _wait();
    if (notFoundMovieIds.contains(movieId)) return null;
    // 목록에도 404 목록에도 없으면 일시적인 네트워크 실패로 본다.
    final found = moviesById[movieId];
    if (found == null) throw failure('/movie/$movieId');
    return found;
  }
}

/// 자체 백엔드 대신 쓰는 가짜 Service. 시드 데이터(수현, noco@umc.com)와 같은 답을 하고,
/// 7주차부터는 평점을 메모리에 들고 있다가 등록·수정·삭제를 실제 서버처럼 반영한다.
class FakeMovieLogApiService implements MovieLogApiService {
  FakeMovieLogApiService({
    Set<String> takenNicknames = const {'수현', '민서'},
    Set<String> takenEmails = const {'noco@umc.com', 'minseo@umc.com'},
    List<MemberRatingDto>? ratings,
  }) : // 테스트가 "확인 직후 누군가 먼저 가입했다"를 만들 수 있게 고칠 수 있는 복사본을 쓴다.
       takenNicknames = {...takenNicknames},
       takenEmails = {...takenEmails},
       ratings = ratings ?? seedRatings;

  final Set<String> takenNicknames;
  final Set<String> takenEmails;
  List<MemberRatingDto> ratings;
  bool fail = false;

  /// 값이 있으면 평점 조회가 이 상태 코드의 응답 오류(400/404 등)로 실패한다.
  int? ratingsStatus;

  /// 값이 있으면 중복 확인 응답을 이 Future가 끝날 때까지 붙잡는다(통신 중 상태 확인용).
  Completer<void>? gate;

  /// 값이 있으면 쓰기(가입·등록·수정·삭제) 응답을 이 Future가 끝날 때까지 붙잡는다.
  Completer<void>? writeGate;

  /// 앞으로 이 횟수만큼의 평점 조회(GET)를 통신 실패로 만든다. 저장은 성공했는데
  /// 재조회만 실패하는 상황을 만들 때 쓴다.
  int failFetchTimes = 0;

  /// 'signUp'·'createRating'·'updateRating'·'deleteRating' → 그 쓰기가 던질 오류.
  /// 한 번 넣으면 테스트가 지울 때까지 계속 던진다.
  final failures = <String, Object>{};

  /// true면 회원가입이 201인데 result 없이 돌아온다(계약 위반).
  bool signUpWithoutResult = false;

  /// 이 ratingId의 삭제만 서버 오류(500)로 실패한다. 다중 삭제에서 일부만 실패하는 상황용.
  final failDeleteIds = <int>{};

  final checkedNicknames = <String>[];
  final checkedEmails = <String>[];
  final ratingMemberIds = <int>[];
  int fetchCalls = 0;

  final signUps = <CreateMemberRequest>[];
  final createdRatings = <({int memberId, CreateRatingRequest request})>[];
  final updatedRatings =
      <({int memberId, int ratingId, UpdateRatingRequest request})>[];
  final deletedRatings = <({int memberId, int ratingId})>[];

  int nextMemberId = 101;
  int _nextRatingId = 100;

  static DioException badResponse(
    String path,
    int statusCode, {
    String? message,
    String? code,
  }) => DioException(
    requestOptions: RequestOptions(path: path),
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: RequestOptions(path: path),
      statusCode: statusCode,
      // 서버의 실패 응답은 공통 틀 { isSuccess, code, message, result } 로 온다.
      data: message == null
          ? null
          : {
              'isSuccess': false,
              'code': code ?? 'COMMON$statusCode',
              'message': message,
              'result': null,
            },
    ),
  );

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

  Future<void> _networkDelay() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (gate != null) await gate!.future;
  }

  Future<void> _writeDelay(String op) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (writeGate != null) await writeGate!.future;
    final error = failures[op];
    if (error != null) throw error;
  }

  @override
  Future<AvailabilityDto> checkNickname(String nickname) async {
    checkedNicknames.add(nickname);
    await _networkDelay();
    if (fail) throw FakeTmdbMovieService.failure('/members/nickname');
    return AvailabilityDto(available: !takenNicknames.contains(nickname));
  }

  @override
  Future<AvailabilityDto> checkEmail(String email) async {
    checkedEmails.add(email);
    await _networkDelay();
    if (fail) throw FakeTmdbMovieService.failure('/members/email');
    return AvailabilityDto(available: !takenEmails.contains(email));
  }

  @override
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    signUps.add(request);
    await _writeDelay('signUp');
    final email = request.email.trim();
    final nickname = request.nickname.trim();
    // 실제 서버처럼 이메일을 먼저 검사한다.
    if (takenEmails.contains(email)) {
      throw badResponse('/members', 409, message: '이미 사용 중인 이메일입니다.');
    }
    if (takenNicknames.contains(nickname)) {
      throw badResponse('/members', 409, message: '이미 사용 중인 닉네임입니다.');
    }
    final id = nextMemberId++;
    return CommonResponse<SignUpResult>(
      isSuccess: true,
      code: 'COMMON201',
      message: '회원가입에 성공했습니다.',
      result: signUpWithoutResult
          ? null
          : SignUpResult(memberId: id, email: email, nickname: nickname),
    );
  }

  @override
  Future<List<MemberRatingDto>> fetchMemberRatings(int memberId) async {
    fetchCalls++;
    ratingMemberIds.add(memberId);
    await _networkDelay();
    final status = ratingsStatus;
    if (status != null) {
      throw badResponse('/members/$memberId/ratings', status);
    }
    if (fail) throw FakeTmdbMovieService.failure('/members/$memberId/ratings');
    if (failFetchTimes > 0) {
      failFetchTimes--;
      throw FakeTmdbMovieService.failure('/members/$memberId/ratings');
    }
    return List.of(ratings);
  }

  @override
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    createdRatings.add((memberId: memberId, request: request));
    await _writeDelay('createRating');
    if (ratings.any((rating) => rating.movieId == request.movieId)) {
      throw badResponse(
        '/members/$memberId/ratings',
        409,
        message: '이미 이 영화에 평점을 남기셨습니다.',
      );
    }
    final now = DateTime.utc(2026, 11, 12);
    ratings = [
      MemberRatingDto(
        ratingId: _nextRatingId++,
        movieId: request.movieId,
        score: request.score,
        comment: request.toJson()['comment'] as String?,
        createdAt: now,
        updatedAt: now,
      ),
      ...ratings,
    ];
  }

  @override
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required UpdateRatingRequest request,
  }) async {
    updatedRatings.add((
      memberId: memberId,
      ratingId: ratingId,
      request: request,
    ));
    await _writeDelay('updateRating');
    final index = ratings.indexWhere((r) => r.ratingId == ratingId);
    if (index < 0) {
      throw badResponse(
        '/members/$memberId/ratings/$ratingId',
        404,
        message: '존재하지 않는 평점입니다.',
      );
    }
    final old = ratings[index];
    ratings = [
      for (final rating in ratings)
        if (rating.ratingId == ratingId)
          MemberRatingDto(
            ratingId: old.ratingId,
            movieId: old.movieId,
            score: request.score,
            comment: request.toJson()['comment'] as String?,
            createdAt: old.createdAt,
            updatedAt: DateTime.utc(2026, 11, 12),
          )
        else
          rating,
    ];
  }

  @override
  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    deletedRatings.add((memberId: memberId, ratingId: ratingId));
    await _writeDelay('deleteRating');
    if (failDeleteIds.contains(ratingId)) {
      throw badResponse(
        '/members/$memberId/ratings/$ratingId',
        500,
        message: '일시적인 서버 오류입니다.',
      );
    }
    if (!ratings.any((r) => r.ratingId == ratingId)) {
      throw badResponse(
        '/members/$memberId/ratings/$ratingId',
        404,
        message: '존재하지 않는 평점입니다.',
      );
    }
    ratings = ratings.where((r) => r.ratingId != ratingId).toList();
  }
}
