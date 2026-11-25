import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/data/models/movie_record_models.dart';
import 'package:movielog/data/models/movielog_dtos.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/movie_record_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/favorite_detail_view_model.dart';
import 'package:movielog/view_models/load_error_message.dart';
import 'package:movielog/view_models/rating_error.dart';
import 'package:movielog/view_models/session_ratings.dart';
import 'package:movielog/view_models/submit_status.dart';

enum MovieDetailLoadStatus { loading, success, error }

/// [MovieDetailViewModel.saveMovieRecord]의 결과. 화면(Dialog)이 다음 행동을 고르는 데 쓴다.
///
/// - 저장 성공: [record]에 서버 응답이 있다.
/// - [closesDialog] false인 실패: 입력을 고치거나 다시 시도할 수 있으니 Dialog를 열어 둔 채
///   [message]를 Dialog 안에 보여 주고 입력(별점·코멘트·체크)은 그대로 둔다.
/// - [closesDialog] true인 실패: 다시 눌러도 소용없는 상황(이미 평점이 있음·이미 즐겨찾기·회원 없음)이라
///   Dialog를 닫고 [message]를 Snackbar로 안내한다.
/// - 둘 다 아니면(record도 message도 null) 지난 세션의 응답이라 아무것도 하지 않는다.
class MovieRecordSaveResult {
  const MovieRecordSaveResult.saved(MovieRecordResponseDto this.record)
    : message = null,
      closesDialog = false;

  const MovieRecordSaveResult.failed(
    String this.message, {
    required this.closesDialog,
  }) : record = null;

  const MovieRecordSaveResult.ignored()
    : record = null,
      message = null,
      closesDialog = false;

  final MovieRecordResponseDto? record;
  final String? message;
  final bool closesDialog;

  bool get isSaved => record != null;
  bool get isIgnored => record == null && message == null;
}

/// 다시 눌러도 결과가 같은 `409`·`404`라서 Dialog를 닫고 Snackbar로 알리는 서버 code들.
const _dialogClosingCodes = {'RATING409_1', 'FAVORITE409_1', 'MEMBER404_1'};

/// 영화 상세 ViewModel. 목록에서 넘겨받은 DTO가 있으면 바로 쓰고,
/// 주소로 바로 열었으면 Route의 TMDB `movieId`로 Movie Details를 조회한다.
///
/// 이 화면에서는 평점 **등록**만 한다(즐겨찾기는 [FavoriteDetailViewModel]이 맡는다). 요청에 memberId가 없고, 누구의 평점인지는 토큰이 알려 준다.
/// 등록 응답으로 받은 평점 객체는 [SessionRatings]에 더해 마이페이지에서 수정·삭제하게 한다.
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(
    this._service,
    this._ratingApi,
    this._auth,
    this._sessionRatings, {
    required this.movieRecordApi,
    required this.movieId,
    this.movie,
  }) : status = movie == null
           ? MovieDetailLoadStatus.loading
           : MovieDetailLoadStatus.success;

  final TmdbMovieService _service;
  final RatingApiService _ratingApi;
  final AuthViewModel _auth;
  final SessionRatings _sessionRatings;

  /// 평점과 즐겨찾기를 한 번에 저장하는 `POST /movie-records`.
  final MovieRecordApiService movieRecordApi;
  final int movieId;
  TmdbMovieDto? movie;
  MovieDetailLoadStatus status;
  String? message;

  /// 이 화면에서 서버 저장까지 마친 평점(1~5). 아직 남기지 않았으면 null.
  MemberRatingDto? myRating;

  /// 평점 등록 요청 상태와, 실패했을 때 사용자에게 보여줄 문구.
  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;

  bool _disposed = false;

  /// 보호 화면이라 보통 항상 true다. 세션이 정리되는 순간 등록 버튼이 잠깐 남지 않게 한다.
  bool get canRate => _auth.isSignedIn;

  Future<void> loadIfNeeded() async {
    if (movie != null) return;
    status = MovieDetailLoadStatus.loading;
    notifyListeners();
    try {
      final result = await _service.fetchMovie(movieId);
      if (_disposed) return;
      movie = result;
      status = MovieDetailLoadStatus.success;
    } catch (error) {
      if (_disposed) return;
      status = MovieDetailLoadStatus.error;
      message = loadErrorMessage(error, fallback: '영화 정보를 불러오지 못했어요.');
    }
    notifyListeners();
  }

  /// 평점 Dialog 결과를 서버에 등록한다. 요청의 movieId는 배열 index가 아니라 TMDB id다.
  ///
  /// 실패해도 예외를 던지지 않고 [submitStatus]·[submitMessage]에 담는다.
  Future<void> createRating({required int score, String? comment}) async {
    if (!_auth.isSignedIn) {
      submitStatus = SubmitStatus.error;
      submitMessage = '로그인이 필요해요.';
      notifyListeners();
      return;
    }
    if (submitStatus == SubmitStatus.submitting) return; // 중복 탭 무시

    final version = _auth.sessionVersion;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    notifyListeners();

    try {
      final rating = await _ratingApi.createRating(
        CreateRatingRequest(movieId: movieId, score: score, comment: comment),
      );
      if (_disposed) return;
      // 로그아웃·다른 계정 로그인 뒤에 늦게 도착한 응답은 새 세션에 반영하지 않는다.
      if (!isSameSession(_auth, version)) return;
      _sessionRatings.add(rating, version: version);
      myRating = rating;
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      final text = await handleRatingError(
        error,
        auth: _auth,
        version: version,
      );
      // 그 사이 다른 로그인 세션이 시작됐으면 이 실패는 지난 일이므로 반영하지 않는다.
      // (이 요청이 401을 받아 세션이 정리된 경우는 signedOut이라 그대로 안내한다.)
      if (_disposed || (_auth.isSignedIn && _auth.sessionVersion != version)) {
        return;
      }
      submitStatus = SubmitStatus.error;
      submitMessage = text;
    } catch (_) {
      // 201이 아닌 성공 응답이나 파싱 실패처럼 계약에서 벗어난 응답. 저장됐는지 알 수 없다.
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      submitMessage = unknownWriteResultMessage;
    }
    notifyListeners();
  }

  /// 평점과 즐겨찾기를 한 번에 저장한다(`POST /movie-records`). 아직 즐겨찾기하지 않은 영화에서만 쓴다.
  ///
  /// 이미 즐겨찾기한 영화는 기존 [createRating](`POST /ratings`)을 쓴다. 실패는 예외 대신 [MovieRecordSaveResult]로
  /// 돌려주고, 같은 요청을 자동으로 다시 보내지 않는다(timeout이면 서버에는 저장됐을 수 있어서, 사용자가 다시 누르면
  /// `RATING409_1`로 알려 준다).
  Future<MovieRecordSaveResult> saveMovieRecord({
    required int score,
    String? comment,
    required bool addToFavorites,
  }) async {
    if (!_auth.isSignedIn) {
      return const MovieRecordSaveResult.failed('로그인이 필요해요.', closesDialog: false);
    }
    if (submitStatus == SubmitStatus.submitting) {
      return const MovieRecordSaveResult.ignored(); // 중복 탭 무시
    }

    final version = _auth.sessionVersion;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    notifyListeners();

    MovieRecordSaveResult result;
    try {
      final record = await movieRecordApi.createRecord(
        CreateMovieRecordRequest(
          movieId: movieId,
          score: score,
          comment: comment,
          addToFavorites: addToFavorites,
        ),
      );
      if (_disposed || !isSameSession(_auth, version)) {
        return const MovieRecordSaveResult.ignored();
      }
      _sessionRatings.add(record.rating, version: version);
      myRating = record.rating;
      submitStatus = SubmitStatus.success;
      result = MovieRecordSaveResult.saved(record);
    } on DioException catch (error) {
      final text = await handleRatingError(
        error,
        auth: _auth,
        version: version,
      );
      if (_disposed || (_auth.isSignedIn && _auth.sessionVersion != version)) {
        return const MovieRecordSaveResult.ignored();
      }
      final code = apiErrorCode(error);
      var message = text;
      // 이미 즐겨찾기한 영화(409)면 서버가 평점도 저장하지 않았다. 그 사실을 함께 알린다.
      if (code == 'FAVORITE409_1') message = '$text 평점은 저장되지 않았어요.';
      submitStatus = SubmitStatus.error;
      submitMessage = message;
      result = MovieRecordSaveResult.failed(
        message,
        closesDialog: _dialogClosingCodes.contains(code),
      );
    } catch (_) {
      // 201이 아닌 성공 응답이나 파싱 실패처럼 계약에서 벗어난 응답. 저장됐는지 알 수 없다.
      if (_disposed) return const MovieRecordSaveResult.ignored();
      submitStatus = SubmitStatus.error;
      submitMessage = unknownWriteResultMessage;
      result = const MovieRecordSaveResult.failed(
        unknownWriteResultMessage,
        closesDialog: false,
      );
    }
    notifyListeners();
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
