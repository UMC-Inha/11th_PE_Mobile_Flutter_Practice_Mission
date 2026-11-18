import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/data/models/movielog_dtos.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/load_error_message.dart';
import 'package:movielog/view_models/rating_error.dart';
import 'package:movielog/view_models/session_ratings.dart';
import 'package:movielog/view_models/submit_status.dart';

enum MovieDetailLoadStatus { loading, success, error }

/// 영화 상세 ViewModel. 목록에서 넘겨받은 DTO가 있으면 바로 쓰고,
/// 주소로 바로 열었으면 Route의 TMDB `movieId`로 Movie Details를 조회한다.
///
/// 이 화면에서는 평점 **등록**만 한다. 요청에 memberId가 없고, 누구의 평점인지는 토큰이 알려 준다.
/// 등록 응답으로 받은 평점 객체는 [SessionRatings]에 더해 마이페이지에서 수정·삭제하게 한다.
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(
    this._service,
    this._ratingApi,
    this._auth,
    this._sessionRatings, {
    required this.movieId,
    this.movie,
  }) : status = movie == null
           ? MovieDetailLoadStatus.loading
           : MovieDetailLoadStatus.success;

  final TmdbMovieService _service;
  final RatingApiService _ratingApi;
  final AuthViewModel _auth;
  final SessionRatings _sessionRatings;
  final int movieId;
  TmdbMovieDto? movie;
  MovieDetailLoadStatus status;
  String? message;

  bool isFavorite = false;

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

  void toggleFavorite() {
    isFavorite = !isFavorite;
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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
