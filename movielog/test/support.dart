import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/storage/genre_preference.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/core/storage/email_preference.dart';
import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/favorite_check_dto.dart';
import 'package:movielog/data/models/favorite_response_dto.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/models/movie_record_models.dart';
import 'package:movielog/data/models/movielog_dtos.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/favorite_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/data/services/movie_record_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/data/services/movielog_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/session_ratings.dart';
import 'package:provider/provider.dart';

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

  /// 이 함수가 있으면 검색 결과를 대신 만든다.
  TmdbMoviePageDto Function(int page, String query)? searchPage;

  /// true면 검색이 실패한다.
  bool failSearch = false;

  /// 이 TMDB id의 영화 조회(`fetchMovie`·`findMovieById`)만 실패한다(영화 한 건 실패 재현).
  final failMovieIds = <int>{};

  /// 값이 있으면 응답을 이 Future가 끝날 때까지 붙잡는다.
  Completer<void>? gate;

  /// Discover·Search 요청마다 불리고, 돌려준 Future가 끝나야 응답이 나간다.
  /// 요청 순서와 응답 순서를 뒤집어(먼저 보낸 요청이 늦게 끝나게) 늦은 응답을 재현할 때 쓴다.
  Future<void> Function(
    ({String kind, int page, List<int>? genreIds, String? query}) call,
  )?
  beforeResponse;

  final discoverCalls = <({int page, List<int>? genreIds})>[];
  final searchCalls = <({int page, String query})>[];
  int popularCalls = 0;
  int genreCalls = 0;
  final movieCalls = <int>[];

  /// 영화 상세 조회가 동시에 몇 개까지 나갔는지(mapBounded 한도 확인용).
  int _inFlightMovieCalls = 0;
  int maxConcurrentMovieCalls = 0;

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
    await beforeResponse?.call((
      kind: 'discover',
      page: page,
      genreIds: genreIds,
      query: null,
    ));
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
  Future<TmdbMoviePageDto> searchMovies({
    required int page,
    required String query,
  }) async {
    searchCalls.add((page: page, query: query));
    await _wait();
    await beforeResponse?.call((
      kind: 'search',
      page: page,
      genreIds: null,
      query: query,
    ));
    if (failSearch) throw failure('/search/movie');
    final custom = searchPage;
    if (custom != null) return custom(page, query);
    return TmdbMoviePageDto(
      page: page,
      results: List.generate(
        perPage,
        (i) => movie(
          (query.hashCode.abs() % 1000) * 1000 + (page - 1) * perPage + i + 1,
          title: '$query 결과 ${(page - 1) * perPage + i + 1}',
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
    _inFlightMovieCalls++;
    if (_inFlightMovieCalls > maxConcurrentMovieCalls) {
      maxConcurrentMovieCalls = _inFlightMovieCalls;
    }
    try {
      await _wait();
      final found = moviesById[movieId];
      if (found == null || failMovieIds.contains(movieId)) {
        throw failure('/movie/$movieId');
      }
      return found;
    } finally {
      _inFlightMovieCalls--;
    }
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
    if (found == null || failMovieIds.contains(movieId)) {
      throw failure('/movie/$movieId');
    }
    return found;
  }
}

/// 실패 응답 `{ isSuccess:false, code, message, result:null }`를 담은 DioException.
DioException apiFailure(
  String path,
  int status, {
  required String code,
  required String message,
}) => DioException(
  requestOptions: RequestOptions(path: path),
  type: DioExceptionType.badResponse,
  response: Response(
    requestOptions: RequestOptions(path: path),
    statusCode: status,
    data: {
      'isSuccess': false,
      'code': code,
      'message': message,
      'result': null,
    },
  ),
);

/// 통신 자체가 실패한 오류(서버 꺼짐). 응답이 없다.
DioException networkFailure(String path) => DioException(
  requestOptions: RequestOptions(path: path),
  type: DioExceptionType.connectionError,
  message: 'network down',
);

/// 응답이 오지 않아 시간 초과로 끝난 오류. 서버에서는 처리됐는지 알 수 없다.
DioException timeoutFailure(String path) => DioException(
  requestOptions: RequestOptions(path: path),
  type: DioExceptionType.receiveTimeout,
  message: 'timeout',
);

/// 로그인된 사용자의 기본 내 정보. 가입일은 시간대에 따라 날짜가 달라지지 않게 정오(로컬)로 둔다.
MemberInfo testMember({
  String nickname = '케빈',
  String email = 'kevin@umc.com',
}) => MemberInfo(
  email: email,
  nickname: nickname,
  createdAt: DateTime(2026, 10, 10, 12),
);

/// 메모리 토큰 저장소. 읽기·쓰기·삭제 실패를 만들 수 있고 호출 횟수를 센다.
class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage({this.token});

  String? token;
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;
  int reads = 0;
  int writes = 0;
  int deletes = 0;

  /// 값이 있으면 저장을 이 Future가 끝날 때까지 붙잡는다.
  Completer<void>? writeGate;

  @override
  Future<void> saveAccessToken(String value) async {
    writes++;
    if (writeGate != null) await writeGate!.future;
    if (failWrite) throw StateError('write failed');
    token = value;
  }

  @override
  Future<String?> readAccessToken() async {
    reads++;
    if (failRead) throw StateError('read failed');
    return token;
  }

  @override
  Future<void> deleteAccessToken() async {
    deletes++;
    if (failDelete) throw StateError('delete failed');
    token = null;
  }
}

class MemoryEmailPreference implements EmailPreference {
  MemoryEmailPreference([this.email]);

  String? email;
  int saves = 0;
  int clears = 0;

  @override
  Future<String?> read() async => email;

  @override
  Future<void> save(String value) async {
    saves++;
    email = value;
  }

  @override
  Future<void> clear() async {
    clears++;
    email = null;
  }
}

/// 로그인 API 대역. 등록된 계정(이메일 → 비밀번호)만 성공한다.
class FakeAuthApiService implements AuthApiService {
  FakeAuthApiService({Map<String, String>? accounts})
    : accounts = {
        ...(accounts ?? const {'kevin@umc.com': 'Password1234!'}),
      };

  final Map<String, String> accounts;
  final nicknames = <String, String>{'kevin@umc.com': '케빈'};

  /// 값이 있으면 로그인이 이 오류로 실패한다(통신 실패·500 등).
  Object? failure;

  /// 값이 있으면 응답을 이 Future가 끝날 때까지 붙잡는다.
  Completer<void>? gate;

  final requests = <LoginRequest>[];
  int _issued = 0;

  /// 마지막으로 발급한 토큰. 테스트가 "화면·로그에 이 값이 없다"를 확인하는 데 쓴다.
  String? lastIssuedToken;

  @override
  Future<LoginResult> login(LoginRequest request) async {
    requests.add(request);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (gate != null) await gate!.future;
    final error = failure;
    if (error != null) throw error;
    final email = request.email.trim();
    if (accounts[email] != request.password) {
      throw apiFailure(
        '/auth/login',
        401,
        code: 'AUTH401_1',
        message: '이메일 또는 비밀번호가 올바르지 않습니다.',
      );
    }
    lastIssuedToken = 'issued-token-${++_issued}';
    return LoginResult(
      nickname: nicknames[email] ?? '회원',
      accessToken: lastIssuedToken!,
    );
  }
}

/// 내 정보 API 대역.
class FakeMemberApiService implements MemberApiService {
  FakeMemberApiService({MemberInfo? member}) : member = member ?? testMember();

  MemberInfo member;
  final takenNicknames = <String>{'수현', '민서'};

  /// 값이 있으면 fetchMe가 이 오류로 실패한다. 한 번 넣으면 지울 때까지 계속 던진다.
  Object? meFailure;

  /// 앞에서부터 하나씩 던지고 비면 정상 응답으로 돌아가는 일회용 오류들.
  final meFailureQueue = <Object>[];

  Completer<void>? meGate;
  Object? updateFailure;
  Completer<void>? updateGate;

  int fetchCalls = 0;
  final updatedNicknames = <String>[];

  @override
  Future<MemberInfo> fetchMe() async {
    fetchCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (meGate != null) await meGate!.future;
    if (meFailureQueue.isNotEmpty) throw meFailureQueue.removeAt(0);
    final error = meFailure;
    if (error != null) throw error;
    return member;
  }

  @override
  Future<MemberInfo> updateNickname(String nickname) async {
    updatedNicknames.add(nickname);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (updateGate != null) await updateGate!.future;
    final error = updateFailure;
    if (error != null) throw error;
    if (takenNicknames.contains(nickname)) {
      throw apiFailure(
        '/members/me',
        409,
        code: 'MEMBER409_1',
        message: '이미 사용 중인 닉네임입니다.',
      );
    }
    member = MemberInfo(
      email: member.email,
      nickname: nickname,
      createdAt: member.createdAt,
    );
    return member;
  }
}

/// 평점 등록·수정·삭제 API 대역(토큰 기반, memberId 없음). 서버 쪽 평점 상태를 들고 있다.
class FakeRatingApiService implements RatingApiService {
  /// 서버에 있는 평점들(ratingId → 평점).
  final serverRatings = <int, MemberRatingDto>{};

  /// 'create'·'update'·'delete' → 그 호출이 던질 오류. 지울 때까지 계속 던진다.
  final failures = <String, Object>{};

  /// 이 ratingId의 삭제만 서버 오류(500)로 실패한다(다중 삭제의 일부 실패용).
  final failDeleteIds = <int>{};

  /// 값이 있으면 쓰기 응답을 이 Future가 끝날 때까지 붙잡는다.
  Completer<void>? writeGate;

  final createdRequests = <CreateRatingRequest>[];
  final updatedCalls = <({int ratingId, UpdateRatingRequest request})>[];
  final deletedIds = <int>[];
  int _nextId = 100;

  Future<void> _delay(String op) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (writeGate != null) await writeGate!.future;
    final error = failures[op];
    if (error != null) throw error;
  }

  @override
  Future<MemberRatingDto> createRating(CreateRatingRequest request) async {
    createdRequests.add(request);
    await _delay('create');
    if (serverRatings.values.any((r) => r.movieId == request.movieId)) {
      throw apiFailure(
        '/ratings',
        409,
        code: 'RATING409_1',
        message: '이미 이 영화에 평점을 남기셨습니다.',
      );
    }
    final now = DateTime.utc(2026, 11, 18);
    final rating = MemberRatingDto(
      ratingId: _nextId++,
      movieId: request.movieId,
      score: request.score,
      comment: request.toJson()['comment'] as String?,
      createdAt: now,
      updatedAt: now,
    );
    serverRatings[rating.ratingId] = rating;
    return rating;
  }

  @override
  Future<MemberRatingDto> updateRating({
    required int ratingId,
    required UpdateRatingRequest request,
  }) async {
    updatedCalls.add((ratingId: ratingId, request: request));
    await _delay('update');
    final old = serverRatings[ratingId];
    if (old == null) {
      throw apiFailure(
        '/ratings/$ratingId',
        404,
        code: 'RATING404_1',
        message: '해당 평점을 찾을 수 없습니다.',
      );
    }
    final updated = MemberRatingDto(
      ratingId: old.ratingId,
      movieId: old.movieId,
      score: request.score,
      comment: request.toJson()['comment'] as String?,
      createdAt: old.createdAt,
      updatedAt: DateTime.utc(2026, 11, 19),
    );
    serverRatings[ratingId] = updated;
    return updated;
  }

  @override
  Future<void> deleteRating(int ratingId) async {
    deletedIds.add(ratingId);
    await _delay('delete');
    if (failDeleteIds.contains(ratingId)) {
      throw apiFailure(
        '/ratings/$ratingId',
        500,
        code: 'COMMON500',
        message: '일시적인 서버 오류입니다.',
      );
    }
    if (serverRatings.remove(ratingId) == null) {
      throw apiFailure(
        '/ratings/$ratingId',
        404,
        code: 'RATING404_1',
        message: '해당 평점을 찾을 수 없습니다.',
      );
    }
  }
}

/// 즐겨찾기 API 대역(토큰 기반, memberId 없음). 서버 쪽 즐겨찾기 상태를 계정별로 들고 있다.
///
/// 실제 서버 계약을 따른다: 등록은 이미 있으면 409(FAVORITE409_1), 해제는 없으면 404(FAVORITE404_1),
/// 목록은 최신 등록순이다. 어느 계정의 요청인지는 [accountOf]가 알려 준다(테스트가 계정 전환을 흉내).
class FakeFavoriteApiService implements FavoriteApiService {
  FakeFavoriteApiService({this.accountOf});

  /// 지금 요청한 계정. null이면 계정 하나만 쓴다.
  String Function()? accountOf;

  final _byAccount = <String, List<FavoriteResponseDto>>{};
  int _nextId = 1;

  /// 'add'·'delete'·'check'·'list' → 그 호출이 던질 오류. 지울 때까지 계속 던진다.
  final failures = <String, Object>{};

  /// 앞에서부터 하나씩 던지고 비면 정상으로 돌아가는 일회용 오류들.
  final failOnce = <String, List<Object>>{};

  /// 이 동작은 서버 상태를 **바꾼 뒤** 응답이 오지 않는다(timeout). 서버에서는 성공한 상황을 재현한다.
  final timeoutAfterApply = <String>{};

  /// 'add'·'delete'·'check'·'list' → 값이 있으면 응답을 이 Future가 끝날 때까지 붙잡는다.
  final gates = <String, Completer<void>>{};

  Duration delay = const Duration(milliseconds: 100);

  final addCalls = <int>[];
  final deleteCalls = <int>[];
  final checkCalls = <int>[];
  int listCalls = 0;

  String get _account => accountOf?.call() ?? 'default';

  List<FavoriteResponseDto> favoritesOf([String? account]) =>
      _byAccount.putIfAbsent(account ?? _account, () => []);

  /// 서버에 즐겨찾기를 심는다. 입력 순서의 **마지막이 가장 최신**이다.
  void seed(List<int> movieIds, {String? account}) {
    for (final movieId in movieIds) {
      favoritesOf(account).insert(
        0,
        FavoriteResponseDto(
          favoriteId: _nextId++,
          movieId: movieId,
          createdAt: DateTime.utc(2026, 11, 20),
        ),
      );
    }
  }

  bool isFavoriteOf(int movieId, {String? account}) =>
      favoritesOf(account).any((item) => item.movieId == movieId);

  Future<void> _enter(String op, String path) async {
    await Future<void>.delayed(delay);
    final gate = gates[op];
    if (gate != null) await gate.future;
    final queued = failOnce[op];
    if (queued != null && queued.isNotEmpty) throw queued.removeAt(0);
    final error = failures[op];
    if (error != null) throw error;
  }

  @override
  Future<FavoriteResponseDto> addFavorite({required int movieId}) async {
    addCalls.add(movieId);
    final account = _account; // 요청을 보낸 시점의 계정
    await _enter('add', '/favorites');
    final list = favoritesOf(account);
    if (list.any((item) => item.movieId == movieId)) {
      throw apiFailure(
        '/favorites',
        409,
        code: 'FAVORITE409_1',
        message: '이미 즐겨찾기한 영화입니다.',
      );
    }
    final created = FavoriteResponseDto(
      favoriteId: _nextId++,
      movieId: movieId,
      createdAt: DateTime.utc(2026, 11, 21),
    );
    list.insert(0, created);
    if (timeoutAfterApply.contains('add')) throw timeoutFailure('/favorites');
    return created;
  }

  @override
  Future<List<FavoriteResponseDto>> fetchMyFavorites() async {
    listCalls++;
    final account = _account;
    await _enter('list', '/favorites');
    return List.of(favoritesOf(account));
  }

  @override
  Future<FavoriteCheckDto> checkFavorite({required int movieId}) async {
    checkCalls.add(movieId);
    final account = _account;
    await _enter('check', '/favorites/$movieId');
    return FavoriteCheckDto(
      movieId: movieId,
      isFavorite: favoritesOf(account).any((item) => item.movieId == movieId),
    );
  }

  @override
  Future<void> deleteFavorite({required int movieId}) async {
    deleteCalls.add(movieId);
    final account = _account;
    await _enter('delete', '/favorites/$movieId');
    final list = favoritesOf(account);
    final before = list.length;
    list.removeWhere((item) => item.movieId == movieId);
    if (list.length == before) {
      throw apiFailure(
        '/favorites/$movieId',
        404,
        code: 'FAVORITE404_1',
        message: '즐겨찾기를 찾을 수 없습니다.',
      );
    }
    if (timeoutAfterApply.contains('delete')) {
      throw timeoutFailure('/favorites/$movieId');
    }
  }
}

/// 평점 + 즐겨찾기 통합 저장(`POST /movie-records`) 대역. 서버 계약대로 둘을 **한 번에** 처리한다:
/// 평점이 이미 있으면 `RATING409_1`, `addToFavorites`인데 즐겨찾기가 이미 있으면 `FAVORITE409_1`(이때 평점도
/// 저장하지 않는다). 성공하면 [ratingApi]·[favoriteApi]가 들고 있는 서버 상태에 실제로 반영한다.
class FakeMovieRecordApiService implements MovieRecordApiService {
  FakeMovieRecordApiService({
    required this.ratingApi,
    required this.favoriteApi,
    this.delay = const Duration(milliseconds: 100),
  });

  final FakeRatingApiService ratingApi;
  final FakeFavoriteApiService favoriteApi;
  Duration delay;

  /// 값이 있으면 요청이 이 오류로 실패한다(지울 때까지 계속). 서버에는 아무것도 저장되지 않는다.
  Object? failure;

  /// 값이 있으면 응답을 이 Future가 끝날 때까지 붙잡는다.
  Completer<void>? gate;

  /// true면 서버에는 저장한 뒤 응답만 오지 않는다(timeout). 자동 재시도 여부를 확인할 때 쓴다.
  bool timeoutAfterApply = false;

  final requests = <CreateMovieRecordRequest>[];

  @override
  Future<MovieRecordResponseDto> createRecord(
    CreateMovieRecordRequest request,
  ) async {
    requests.add(request);
    await Future<void>.delayed(delay);
    if (gate != null) await gate!.future;
    final error = failure;
    if (error != null) throw error;
    if ((request.comment ?? '').length > 500) {
      throw apiFailure(
        '/movie-records',
        400,
        code: 'COMMON400',
        message: '코멘트는 500자 이하로 입력해 주세요.',
      );
    }
    if (ratingApi.serverRatings.values.any((r) => r.movieId == request.movieId)) {
      throw apiFailure(
        '/movie-records',
        409,
        code: 'RATING409_1',
        message: '이미 이 영화에 평점을 남기셨습니다.',
      );
    }
    if (request.addToFavorites && favoriteApi.isFavoriteOf(request.movieId)) {
      throw apiFailure(
        '/movie-records',
        409,
        code: 'FAVORITE409_1',
        message: '이미 즐겨찾기한 영화입니다.',
      );
    }
    final now = DateTime.utc(2026, 11, 22);
    final rating = MemberRatingDto(
      ratingId: ratingApi._nextId++,
      movieId: request.movieId,
      score: request.score,
      comment: request.toJson()['comment'] as String?,
      createdAt: now,
      updatedAt: now,
    );
    ratingApi.serverRatings[rating.ratingId] = rating;
    FavoriteResponseDto? favorite;
    if (request.addToFavorites) {
      favorite = FavoriteResponseDto(
        favoriteId: favoriteApi._nextId++,
        movieId: request.movieId,
        createdAt: now,
      );
      favoriteApi.favoritesOf().insert(0, favorite);
    }
    if (timeoutAfterApply) throw timeoutFailure('/movie-records');
    return MovieRecordResponseDto(rating: rating, favorite: favorite);
  }
}

/// 공개 MovieLog API 대역(중복 확인, 회원가입, 유저별 평점 조회). 시드 데이터(수현, noco@umc.com)와 같은 답을 한다.
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

  /// 값이 있으면 평점 조회가 이 상태 코드의 응답 오류로 실패한다.
  int? ratingsStatus;

  /// 값이 있으면 중복 확인 응답을 이 Future가 끝날 때까지 붙잡는다(통신 중 상태 확인용).
  Completer<void>? gate;

  /// 값이 있으면 회원가입 응답을 이 Future가 끝날 때까지 붙잡는다.
  Completer<void>? writeGate;

  /// 'signUp' → 회원가입이 던질 오류. 지울 때까지 계속 던진다.
  final failures = <String, Object>{};

  /// true면 회원가입이 201인데 result 없이 돌아온다(계약 위반).
  bool signUpWithoutResult = false;

  final checkedNicknames = <String>[];
  final checkedEmails = <String>[];
  final ratingMemberIds = <int>[];
  int fetchCalls = 0;
  final signUps = <CreateMemberRequest>[];
  int nextMemberId = 101;

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
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (writeGate != null) await writeGate!.future;
    final error = failures['signUp'];
    if (error != null) throw error;
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
    return List.of(ratings);
  }
}

/// 앱 전체를 가짜 Service로 조립하는 하니스. 기본은 **저장된 토큰이 있고 서버도 그 토큰을
/// 인정하는** 상태라서, 앱을 켜면 세션 복원을 거쳐 홈으로 간다.
///
/// 로그아웃 상태로 시작하려면 `storage.token = null`.
class AppHarness {
  AppHarness({String? token = 'stored-token', MemberInfo? member})
    : storage = FakeTokenStorage(token: token),
      memberApi = FakeMemberApiService(member: member) {
    // 즐겨찾기는 계정별이다. 지금 내 정보 대역이 돌려주는 계정의 즐겨찾기를 다룬다.
    favoriteApi = FakeFavoriteApiService(accountOf: () => memberApi.member.email);
    movieRecordApi = FakeMovieRecordApiService(
      ratingApi: ratingApi,
      favoriteApi: favoriteApi,
    );
  }

  final FakeTmdbMovieService tmdb = FakeTmdbMovieService();
  final FakeMovieLogApiService publicApi = FakeMovieLogApiService();
  final FakeAuthApiService authApi = FakeAuthApiService();
  final FakeMemberApiService memberApi;
  final FakeRatingApiService ratingApi = FakeRatingApiService();
  late final FakeFavoriteApiService favoriteApi;
  late final FakeMovieRecordApiService movieRecordApi;
  final FakeTokenStorage storage;
  final MemoryEmailPreference emailPreference = MemoryEmailPreference();

  /// [tmdbService]를 주면 기본 TMDB 대역 대신 그것을 쓴다(인증 이미지 테스트용).
  Widget app({
    String initialLocation = '/',
    Key? key,
    TmdbMovieService? tmdbService,
  }) => MovieLogApp(
    key: key,
    initialLocation: initialLocation,
    tmdbService: tmdbService ?? tmdb,
    movieLogApiService: publicApi,
    authApiService: authApi,
    memberApiService: memberApi,
    ratingApiService: ratingApi,
    favoriteApiService: favoriteApi,
    movieRecordApiService: movieRecordApi,
    tokenStorage: storage,
    emailPreference: emailPreference,
    preferences: MemoryMoviePreferences(),
  );
}

/// 지금 떠 있는 앱의 GoRouter를 꺼내 주소로 이동한다(테스트 전용).
void goTo(WidgetTester tester, String location) {
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).go(location);
}

/// 지금 Router의 현재 위치.
String currentLocation(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold).first);
  return GoRouter.of(context).state.uri.path;
}

/// 지금 떠 있는 앱의 AuthViewModel(테스트 전용).
AuthViewModel authOf(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first).read<AuthViewModel>();

/// 지금 떠 있는 앱의 이번 세션 평점 목록(테스트 전용).
SessionRatings sessionOf(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first).read<SessionRatings>();

/// 서버 대역과 이번 세션 목록 양쪽에 평점을 심는다. 입력 순서가 목록 순서다.
/// 서버 쪽에도 있어야 수정·삭제 요청이 404가 되지 않는다.
void seedRatings(
  WidgetTester tester,
  AppHarness harness,
  List<MemberRatingDto> ratings,
) {
  final auth = authOf(tester);
  final session = sessionOf(tester);
  for (final rating in ratings.reversed) {
    harness.ratingApi.serverRatings[rating.ratingId] = rating;
    session.add(rating, version: auth.sessionVersion);
  }
}

/// 요청을 기록하고 정해 둔 응답을 돌려주는 Dio 어댑터. 요청 헤더를 확인하는 테스트용이다.
class StubAdapter implements HttpClientAdapter {
  StubAdapter([this.respond]);

  /// (상태 코드, 본문). null이면 `200 {}`.
  final (int, Object?) Function(RequestOptions options)? respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = respond?.call(options) ?? (200, <String, Object?>{});
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
