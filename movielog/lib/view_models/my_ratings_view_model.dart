import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/data/models/movielog_dtos.dart';
import 'package:movielog/data/models/rating_with_movie.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/rating_error.dart';
import 'package:movielog/view_models/session_ratings.dart';
import 'package:movielog/view_models/submit_status.dart';

/// "내가 등록한 평점" 화면 ViewModel.
///
/// 평점(점수·후기·movieId)은 [SessionRatings], 제목·포스터는 그 movieId로 TMDB에서 가져와
/// [RatingWithMovie]로 묶는다. **서버에서 내 평점 목록을 읽지 않는다**(그런 API가 없다).
/// 이번 로그인에서 등록한 평점만 있고 앱을 다시 켜면 비어 있다.
///
/// - TMDB에서 못 찾은 영화도 평점은 지우지 않고 `영화 #{movieId}` placeholder로 보여준다.
/// - 수정·삭제는 응답으로 받은 평점 객체(또는 성공)로 [SessionRatings]를 바꾼다. 다시 조회할 목록이 없다.
/// - 모든 쓰기는 보낼 때의 sessionVersion을 기억해 로그아웃·계정 전환 뒤 늦게 온 응답을 버린다.
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._ratingApi, this._tmdb, this._auth, this._session) {
    _session.addListener(_onSessionChanged);
  }

  final RatingApiService _ratingApi;
  final TmdbMovieService _tmdb;
  final AuthViewModel _auth;
  final SessionRatings _session;

  /// 같은 movieId는 한 번만 조회한다. TMDB가 404를 준 영화는 null로 캐시해 다시 묻지 않고,
  /// 일시적인 네트워크 실패는 캐시하지 않아 다음에 다시 시도한다.
  final Map<int, TmdbMovieDto?> _movieCache = {};
  final Set<int> _lookingUp = {};

  /// 일부 영화 정보를 가져오지 못했다는 안내(없으면 null).
  String? message;

  // ── 편집(다중 선택 삭제) Challenge ──
  bool isEditing = false;
  final Set<int> selectedRatingIds = {};

  /// 선택한 평점을 하나씩 지우는 동안 true. 화면이 로딩 오버레이와 이탈 방지를 건다.
  bool isDeletingSelected = false;

  bool _disposed = false;

  List<RatingWithMovie> get ratings => [
    for (final rating in _session.ratings)
      RatingWithMovie(rating: rating, movie: _movieCache[rating.movieId]),
  ];

  bool get isEmpty => _session.ratings.isEmpty;

  double? get averageScore {
    final list = _session.ratings;
    if (list.isEmpty) return null;
    return list.fold<int>(0, (sum, item) => sum + item.score) / list.length;
  }

  /// 아직 모르는 영화의 제목·포스터를 TMDB에서 찾아 온다. 화면이 열릴 때 한 번 부른다.
  Future<void> loadMovies() async {
    final unknown = _session.ratings
        .map((rating) => rating.movieId)
        .where((id) => !_movieCache.containsKey(id) && !_lookingUp.contains(id))
        .toSet();
    if (unknown.isEmpty) {
      _updateMessage();
      return;
    }
    _lookingUp.addAll(unknown);
    await Future.wait(unknown.map(_lookupMovie));
    _lookingUp.removeAll(unknown);
    if (_disposed) return;
    _updateMessage();
    notifyListeners();
  }

  Future<void> _lookupMovie(int movieId) async {
    try {
      _movieCache[movieId] = await _tmdb.findMovieById(movieId);
    } catch (_) {
      // 일시적 실패는 캐시하지 않는다. 평점은 그대로 보여주고 placeholder를 쓴다.
    }
  }

  void _updateMessage() {
    final missing = _session.ratings.any(
      (rating) => _movieCache[rating.movieId] == null,
    );
    message = missing ? '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.' : null;
  }

  void _onSessionChanged() {
    if (_disposed) return;
    final ids = _session.ratings.map((rating) => rating.ratingId).toSet();
    selectedRatingIds.removeWhere((id) => !ids.contains(id));
    // 평점이 하나도 남지 않으면 편집할 것이 없으니 기본 화면으로 돌아간다.
    if (ids.isEmpty && !isDeletingSelected) isEditing = false;
    _updateMessage();
    notifyListeners();
    loadMovies(); // 새로 생긴 평점의 영화 정보를 가져온다.
  }

  /// 평점 하나를 수정한다. score와 comment를 항상 함께 보내고, 후기를 비우면 null이다(삭제 의도).
  ///
  /// 실패하면 [RatingSaveException]을 던져 Dialog가 사유를 보여주게 한다.
  /// 401(AUTH401_2/3/4)은 세션을 정리하고, 403은 안내만 하며 로그아웃하지 않는다.
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    if (!_auth.isSignedIn) throw const RatingSaveException('로그인이 필요해요.');
    final version = _auth.sessionVersion;
    try {
      final updated = await _ratingApi.updateRating(
        ratingId: ratingId,
        request: UpdateRatingRequest(score: score, comment: comment),
      );
      _session.replace(updated, version: version);
    } on DioException catch (error) {
      throw RatingSaveException(
        await _failureText(error, ratingId: ratingId, version: version),
      );
    } catch (_) {
      throw const RatingSaveException(unknownWriteResultMessage);
    }
  }

  /// 평점 하나를 삭제한다. 성공은 200 + `result: null`이고, 마지막 항목을 지우면 Empty가 된다.
  Future<void> deleteRating(int ratingId) async {
    if (!_auth.isSignedIn) throw const RatingSaveException('로그인이 필요해요.');
    final version = _auth.sessionVersion;
    try {
      await _ratingApi.deleteRating(ratingId);
      _session.remove(ratingId, version: version);
      selectedRatingIds.remove(ratingId);
    } on DioException catch (error) {
      throw RatingSaveException(
        await _failureText(error, ratingId: ratingId, version: version),
      );
    } catch (_) {
      throw const RatingSaveException(unknownWriteResultMessage);
    }
  }

  /// 쓰기 실패 문구. 서버가 "그런 평점이 없다(404)"고 하면 화면에 남은 항목도 치운다.
  Future<String> _failureText(
    DioException error, {
    required int ratingId,
    required int version,
  }) async {
    final text = await handleRatingError(error, auth: _auth, version: version);
    if (error.response?.statusCode == 404) {
      _session.remove(ratingId, version: version);
    }
    return text;
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
  /// 실패한 항목은 선택 상태를 유지해 다시 시도할 수 있게 한다. 세션이 끝났으면(401·로그아웃) 중단한다.
  ///
  /// 돌려주는 값은 (삭제 성공 수, 삭제 실패 수)다.
  Future<({int deleted, int failed})> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty || !_auth.isSignedIn) {
      return (deleted: 0, failed: 0);
    }
    final version = _auth.sessionVersion;
    isDeletingSelected = true;
    notifyListeners();

    var deleted = 0;
    var failed = 0;
    // 원본 Set을 순회하면서 remove하면 ConcurrentModificationError가 나므로 복사본을 돈다.
    final targets = selectedRatingIds.toList();
    try {
      for (var i = 0; i < targets.length; i++) {
        final ratingId = targets[i];
        try {
          await _ratingApi.deleteRating(ratingId);
          _session.remove(ratingId, version: version);
          selectedRatingIds.remove(ratingId);
          deleted++;
        } on DioException catch (error) {
          failed++; // 실패한 항목은 선택 상태를 유지한다.
          await handleRatingError(error, auth: _auth, version: version);
          if (!isSameSession(_auth, version)) {
            failed += targets.length - i - 1; // 세션이 끝났으니 나머지는 시도하지 않는다.
            break;
          }
        } catch (_) {
          failed++;
        }
        if (_disposed || !isSameSession(_auth, version)) {
          if (!_disposed && deleted + failed < targets.length) {
            failed += targets.length - deleted - failed;
          }
          break;
        }
      }
    } finally {
      isDeletingSelected = false;
      if (selectedRatingIds.isEmpty) isEditing = false; // 전부 지웠으면 기본 목록으로 돌아간다.
      if (!_disposed) notifyListeners();
    }
    return (deleted: deleted, failed: failed);
  }

  @override
  void dispose() {
    _disposed = true;
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }
}
