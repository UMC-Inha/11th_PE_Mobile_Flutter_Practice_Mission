import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/data/models/movielog_dtos.dart';
import 'package:movielog/data/models/rating_with_movie.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/movielog_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/load_error_message.dart';
import 'package:movielog/view_models/submit_status.dart';
import 'package:movielog/view_models/write_error_message.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

/// "내가 등록한 평점" 화면 ViewModel.
///
/// 평점(점수·후기·movieId)은 자체 백엔드 `GET /members/{memberId}/ratings`에서,
/// 제목·포스터는 그 movieId로 TMDB에서 가져와 [RatingWithMovie]로 묶는다.
/// - 평점이 0개(빈 배열)인 것은 [MyRatingsLoadStatus.empty], 요청 실패는 error로 구분한다.
/// - TMDB 영화 조회가 실패해도 평점 목록은 지우지 않는다(그 영화만 placeholder).
///
/// 7주차부터 수정·삭제(단건, 다중)도 이 ViewModel이 맡는다. 쓰기 요청이 성공하면 목록을 다시
/// 조회해 서버 상태와 맞추는데, **저장 성공과 재조회 실패는 다른 상태**다. 저장이 끝났는데
/// GET만 실패했다면 쓰기를 실패로 취급하지 않고 [refreshWarning]으로 "조회만 다시" 안내한다.
class MyRatingsViewModel extends ChangeNotifier {
  /// [memberId]는 회원가입 결과를 보관한 학습용 세션의 값이다. 로그인(인증)된 회원이 아니다.
  MyRatingsViewModel(this._api, this._tmdb, {required this.memberId});

  final MovieLogApiService _api;
  final TmdbMovieService _tmdb;
  final int memberId;

  /// 같은 movieId는 한 번만 조회한다. TMDB가 404를 준 영화는 null로 캐시해 다시 묻지 않고,
  /// 일시적인 네트워크 실패는 캐시하지 않아 다음 load에서 다시 시도한다.
  final Map<int, TmdbMovieDto?> _movieCache = {};

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;

  /// error일 때 오류 문구, success일 때 일부 영화 정보를 못 가져왔다는 안내(없으면 null).
  String? message;

  /// 쓰기는 성공했지만 그 뒤 목록 재조회가 실패했을 때의 안내. 쓰기 실패와 구분하려고 따로 둔다.
  String? refreshWarning;

  // ── 편집(다중 선택 삭제) Challenge ──
  /// true면 카드의 수정·삭제 버튼 대신 체크박스를 보여준다.
  bool isEditing = false;

  /// 선택한 ratingId. 삭제에 실패한 항목은 그대로 남겨 다시 시도하게 한다.
  final Set<int> selectedRatingIds = {};

  /// 선택한 평점을 하나씩 지우는 동안 true. 화면이 로딩 오버레이와 이탈 방지를 건다.
  bool isDeletingSelected = false;

  int _requestVersion = 0;
  bool _disposed = false;

  double? get averageScore {
    if (ratings.isEmpty) return null;
    final total = ratings.fold<int>(
      0,
      (sum, entry) => sum + entry.rating.score,
    );
    return total / ratings.length;
  }

  /// 목록을 조회한다. [silent]면 쓰기 직후의 재조회라 목록을 로딩 표시로 바꾸지 않는다
  /// (저장 성공 뒤 화면이 깜빡이며 비는 것을 막는다). 실패하면 어느 쪽이든 error 상태가 된다.
  Future<void> load({bool silent = false}) async {
    final version = ++_requestVersion;
    if (!silent) {
      status = MyRatingsLoadStatus.loading;
      message = null;
      refreshWarning = null;
      notifyListeners();
    }

    try {
      final rawRatings = await _api.fetchMemberRatings(memberId);
      if (_isStale(version)) return;

      // 같은 영화를 두 번 조회하지 않게 아직 모르는 movieId만 모아 한꺼번에 묻는다.
      final unknownIds = rawRatings
          .map((rating) => rating.movieId)
          .where((id) => !_movieCache.containsKey(id))
          .toSet();
      await Future.wait(unknownIds.map(_lookupMovie));
      if (_isStale(version)) return;

      var missingMovies = 0;
      final entries = <RatingWithMovie>[];
      for (final rating in rawRatings) {
        final movie = _movieCache[rating.movieId];
        if (movie == null) missingMovies++;
        entries.add(RatingWithMovie(rating: rating, movie: movie));
      }

      ratings = entries;
      // 서버에서 사라진 평점이 선택 목록에 남아 있지 않게 한다.
      selectedRatingIds.removeWhere(
        (id) => !entries.any((entry) => entry.rating.ratingId == id),
      );
      status = entries.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
      message = missingMovies > 0
          ? '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.'
          : null;
      refreshWarning = null;
    } catch (error) {
      if (_isStale(version)) return;
      status = MyRatingsLoadStatus.error;
      message = myRatingsErrorMessage(error);
    }
    notifyListeners();
  }

  Future<void> _lookupMovie(int movieId) async {
    try {
      _movieCache[movieId] = await _tmdb.findMovieById(movieId);
    } catch (_) {
      // 일시적 실패는 캐시하지 않는다. 평점 목록은 그대로 보여주고 다음 load에서 다시 시도한다.
    }
  }

  /// 쓰기가 성공한 뒤 서버 목록과 맞춘다. 재조회가 실패해도 쓰기를 실패로 다시 던지지 않는다.
  Future<void> _refreshAfterWrite() async {
    await load(silent: true);
    if (_disposed) return;
    if (status == MyRatingsLoadStatus.error) {
      refreshWarning = '저장은 완료됐지만 목록을 불러오지 못했습니다. 조회만 다시 시도해 주세요.';
      notifyListeners();
    }
  }

  /// 평점 하나를 수정한다. score는 항상 보내고, 후기는 비어 있으면 지운다는 뜻으로 null을 보낸다.
  ///
  /// 쓰기 요청이 실패하면 [RatingSaveException]을 던져 Dialog가 서버 문구를 보여주게 한다.
  /// 성공한 뒤 목록 재조회가 실패하는 것은 예외가 아니라 [refreshWarning]이다.
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    try {
      await _api.updateRating(
        memberId: memberId,
        ratingId: ratingId,
        request: UpdateRatingRequest(score: score, comment: comment),
      );
    } on DioException catch (error) {
      await _handleWriteFailure(error);
    } on StateError {
      throw const RatingSaveException('저장 결과를 확인하지 못했습니다. 목록을 새로 불러와 확인해 주세요.');
    }
    await _refreshAfterWrite();
  }

  /// 평점 하나를 삭제한다. 204 응답은 본문이 없고, 마지막 항목을 지우면 Empty 상태가 된다.
  Future<void> deleteRating(int ratingId) async {
    try {
      await _api.deleteRating(memberId: memberId, ratingId: ratingId);
    } on DioException catch (error) {
      await _handleWriteFailure(error);
    } on StateError {
      throw const RatingSaveException('삭제 결과를 확인하지 못했습니다. 목록을 새로 불러와 확인해 주세요.');
    }
    selectedRatingIds.remove(ratingId);
    await _refreshAfterWrite();
  }

  /// 쓰기 실패를 사용자 문구로 바꿔 다시 던진다. 403·404면 화면의 목록이 서버와 어긋난
  /// 것이므로 먼저 조용히 다시 조회해 맞춘다.
  Future<Never> _handleWriteFailure(DioException error) async {
    final text = writeErrorMessage(error);
    if (shouldRefreshAfterRatingError(error)) await load(silent: true);
    throw RatingSaveException(text);
  }

  // ── 편집 모드 ──

  void startEditing() {
    if (isEditing || isDeletingSelected) return;
    isEditing = true;
    selectedRatingIds.clear();
    notifyListeners();
  }

  void cancelEditing() {
    if (!isEditing || isDeletingSelected) return;
    isEditing = false;
    selectedRatingIds.clear();
    notifyListeners();
  }

  void toggleSelection(int ratingId) {
    if (!isEditing || isDeletingSelected) return;
    if (!selectedRatingIds.add(ratingId)) selectedRatingIds.remove(ratingId);
    notifyListeners();
  }

  /// 선택한 평점을 순서대로 하나씩 지운다. 일부만 실패하면 성공한 항목만 목록에서 사라지고,
  /// 실패한 항목은 선택 상태를 유지해 다시 시도할 수 있게 한다.
  ///
  /// 돌려주는 값은 (삭제 성공 수, 삭제 실패 수)다. 화면이 일부 실패 Snackbar를 띄우는 데 쓴다.
  Future<({int deleted, int failed})> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty) {
      return (deleted: 0, failed: 0);
    }
    isDeletingSelected = true;
    notifyListeners();

    var deleted = 0;
    var failed = 0;
    try {
      // 원본 Set을 순회하면서 remove하면 ConcurrentModificationError가 나므로 복사본을 돈다.
      for (final ratingId in selectedRatingIds.toList()) {
        try {
          await _api.deleteRating(memberId: memberId, ratingId: ratingId);
          selectedRatingIds.remove(ratingId);
          deleted++;
        } on DioException {
          failed++; // 실패한 항목은 선택 상태를 유지한다.
        } on StateError {
          failed++;
        }
        if (_disposed) return (deleted: deleted, failed: failed);
      }
      // 삭제 성공 여부와 별개로 서버 상태에 맞춘다. 재조회 실패는 refreshWarning으로 분리된다.
      await _refreshAfterWrite();
    } finally {
      isDeletingSelected = false;
      if (selectedRatingIds.isEmpty) isEditing = false; // 전부 지웠으면 기본 목록으로 돌아간다.
      if (!_disposed) notifyListeners();
    }
    return (deleted: deleted, failed: failed);
  }

  bool _isStale(int version) => _disposed || version != _requestVersion;

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}

/// 평점 조회 실패를 원인별 문구로 바꾼다. 400(형식 오류)·404(없는 회원)·그 밖의 통신 실패를
/// 하나의 "실패"로 뭉치지 않는다. 평점이 없는 회원은 200 `[]`라서 여기에 오지 않는다.
String myRatingsErrorMessage(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == 400) return 'memberId 형식을 다시 확인해 주세요.';
    if (status == 404) return '존재하지 않는 회원입니다.';
  }
  return loadErrorMessage(
    error,
    fallback: '평점을 불러오지 못했어요. 서버가 켜져 있는지 확인해 주세요.',
  );
}
