import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_request.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import 'submit_status.dart';

export 'submit_status.dart';

/// 영화 상세 화면의 영화 DTO와 평점 등록 상태를 관리합니다.
/// 평점 조회·수정·삭제는 마이페이지의 "내가 등록한 평점" 화면이 담당합니다.
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(this._ratingService, this.memberId, this.movie);
  final RatingApiService _ratingService;

  /// 학습용 현재 회원입니다. 로그인 인증은 아닙니다. 가입 전이면 null입니다.
  final int? memberId;
  final TmdbMovieDto movie;

  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;

  /// 이 화면에서 방금 등록에 성공한 별점입니다.
  int? myScore;

  bool _disposed = false;

  bool get canRate => memberId != null;

  Future<void> createRating({required int score, String? comment}) async {
    final id = memberId;
    if (id == null) {
      submitStatus = SubmitStatus.error;
      submitMessage = '먼저 회원가입을 완료해 주세요.';
      notifyListeners();
      return;
    }
    if (submitStatus == SubmitStatus.submitting) return;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    notifyListeners();

    try {
      await _ratingService.createRating(
        memberId: id,
        // movieId는 영화 배열 index가 아니라 TMDB 영화 id입니다.
        request: CreateRatingRequest(
          movieId: movie.id,
          score: score,
          comment: comment,
        ),
      );
      if (_disposed) return;
      submitStatus = SubmitStatus.success;
      myScore = score;
    } on DioException catch (error) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      submitMessage = writeErrorMessage(error);
    } on StateError {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      submitMessage = '등록 결과를 확인하지 못했습니다. 마이페이지에서 등록 여부를 확인해 주세요.';
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
