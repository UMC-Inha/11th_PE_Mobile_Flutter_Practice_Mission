import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/rating_request.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import 'auth_view_model.dart';
import 'session_rating_store.dart';
import 'submit_status.dart';

export 'submit_status.dart';

/// 영화 상세 화면의 영화 DTO와 평점 등록 상태를 관리합니다.
/// 평점 수정·삭제는 마이페이지의 "내가 등록한 평점" 화면이 담당합니다.
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(this._ratingService, this._auth, this._store, this.movie);
  final RatingApiService _ratingService;
  final AuthViewModel _auth;
  final SessionRatingStore _store;
  final TmdbMovieDto movie;

  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;

  /// 이 화면에서 방금 등록에 성공한 별점입니다.
  int? myScore;

  bool _disposed = false;

  Future<void> createRating({required int score, String? comment}) async {
    if (submitStatus == SubmitStatus.submitting) return;
    final version = _auth.sessionVersion;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    notifyListeners();

    try {
      // 등록 요청 body에는 memberId를 넣지 않습니다.
      final created = await _ratingService.createRating(
        // movieId는 영화 배열 index가 아니라 TMDB 영화 id입니다.
        CreateRatingRequest(movieId: movie.id, score: score, comment: comment),
      );
      if (_disposed || version != _auth.sessionVersion) return;
      // 등록 result의 Rating 객체로 현재 작업 카드를 갱신합니다.
      _store.upsert(created, sessionVersion: version);
      submitStatus = SubmitStatus.success;
      myScore = created.score;
    } on DioException catch (error) {
      if (_disposed || version != _auth.sessionVersion) return;
      final code = apiErrorCode(error);
      if (code == 'AUTH401_2' || code == 'AUTH401_3' || code == 'AUTH401_4') {
        await _auth.expireSession();
        return;
      }
      // 403·409는 어떤 오류가 발생했는지 안내만 하고 로그아웃하지 않습니다.
      submitStatus = SubmitStatus.error;
      submitMessage = writeErrorMessage(error);
    } on StateError {
      if (_disposed || version != _auth.sessionVersion) return;
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
