import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/data/models/movielog_dtos.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/movielog_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/load_error_message.dart';
import 'package:movielog/view_models/submit_status.dart';
import 'package:movielog/view_models/write_error_message.dart';

enum MovieDetailLoadStatus { loading, success, error }

/// 영화 상세 ViewModel. 목록에서 넘겨받은 DTO가 있으면 바로 쓰고,
/// 주소로 바로 열었으면 Route의 TMDB `movieId`로 Movie Details를 조회한다.
///
/// 이 화면에서는 평점 **등록**만 한다. 조회·수정·삭제는 마이페이지의 "내가 등록한 평점"이 맡는다.
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(
    this._service,
    this._ratingApi, {
    required this.movieId,
    this.movie,
    this.memberId,
  }) : status = movie == null
           ? MovieDetailLoadStatus.loading
           : MovieDetailLoadStatus.success;

  final TmdbMovieService _service;
  final MovieLogApiService _ratingApi;
  final int movieId;

  /// 회원가입 결과로 보관한 학습용 현재 회원. 로그인(인증)이 아니고, 없으면 평점을 등록할 수 없다.
  final int? memberId;
  TmdbMovieDto? movie;
  MovieDetailLoadStatus status;
  String? message;

  bool isFavorite = false;

  /// 이 화면에서 서버 저장까지 마친 평점(1~5). 아직 남기지 않았으면 null.
  CreateRatingRequest? myRating;

  /// 평점 등록 요청 상태와, 실패했을 때 서버가 내려 준 안내 문구.
  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;

  bool _disposed = false;

  bool get canRate => memberId != null;

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
  /// 400(별점 범위)·409(이미 등록)·404(없는 유저)의 문구는 서버 message를 그대로 쓴다.
  /// 같은 화면에서 값을 고치거나 다시 시도하면 되는 오류라 목록을 다시 조회하지 않는다.
  Future<void> createRating({required int score, String? comment}) async {
    final id = memberId;
    if (id == null) {
      submitStatus = SubmitStatus.error;
      submitMessage = '먼저 회원가입을 완료해 주세요.';
      notifyListeners();
      return;
    }
    if (submitStatus == SubmitStatus.submitting) return; // 중복 탭 무시

    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    notifyListeners();

    final request = CreateRatingRequest(
      movieId: movieId,
      score: score,
      comment: comment,
    );
    try {
      await _ratingApi.createRating(memberId: id, request: request);
      if (_disposed) return;
      myRating = request;
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      submitMessage = writeErrorMessage(error);
    } on StateError {
      // 201이 아닌 성공 응답처럼 계약에서 벗어난 응답. 저장됐는지 알 수 없다.
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      submitMessage = '저장 결과를 확인하지 못했습니다. 마이페이지에서 등록 여부를 확인해 주세요.';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
