import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/session/session_guard.dart';
import '../core/utils/safe_notify.dart';
import '../data/services/favorite_api_service.dart';

/// 세션 만료로 판단하는 서버 오류 code입니다. 로그인 실패(AUTH401_1)와 403은 포함하지 않습니다.
bool isSessionExpiredError(Object error) {
  if (error is! DioException) return false;
  final code = apiErrorCode(error);
  return code == 'AUTH401_2' || code == 'AUTH401_3' || code == 'AUTH401_4';
}

/// 영화 상세 화면의 즐겨찾기(북마크) 상태를 관리합니다.
/// 서버 성공을 확인한 뒤에만 북마크를 바꿉니다. (optimistic update 사용 안 함)
class FavoriteDetailViewModel extends ChangeNotifier with SafeNotify {
  FavoriteDetailViewModel({
    required this.movieId,
    required this.favoriteApi,
    required this.sessionGuard,
    required this.accountId,
    required this.onSessionExpired,
  });

  // 상세 화면의 TMDB 영화 ID입니다. 즐겨찾기 경로에는 favoriteId가 아니라 이 값을 씁니다.
  final int movieId;
  final FavoriteApiService favoriteApi;
  final SessionGuard sessionGuard;
  final String accountId;

  /// 현재 세션의 요청이 만료 code를 받았을 때만 호출합니다. (8주차 AuthViewModel.expireSession)
  final Future<void> Function() onSessionExpired;

  bool isFavorite = false;
  bool hasLoadedStatus = false;
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  ({int generation, bool ok}) _snapshot() {
    final generation = sessionGuard.generation;
    return (
      generation: generation,
      ok: sessionGuard.isCurrent(generation, accountId) && !isDisposed,
    );
  }

  bool _isStale(int generation) =>
      !sessionGuard.isCurrent(generation, accountId) || isDisposed;

  Future<void> load() async {
    if (isLoading || isSaving) return;
    final snap = _snapshot();
    if (!snap.ok) return;
    isLoading = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      final result = await favoriteApi.checkFavorite(movieId: movieId);
      if (_isStale(snap.generation)) return;
      isFavorite = result.isFavorite;
      hasLoadedStatus = true;
    } catch (error) {
      if (_isStale(snap.generation)) return;
      if (isSessionExpiredError(error)) {
        await onSessionExpired();
        return;
      }
      errorMessage = '즐겨찾기 여부를 확인하지 못했습니다.';
    } finally {
      if (!_isStale(snap.generation)) {
        isLoading = false;
        notifyIfAlive();
      }
    }
  }

  /// 등록·해제를 요청하고, 화면에 Snackbar로 보여줄 문구를 반환합니다.
  /// 요청을 보내지 않았거나 세션이 바뀌어 결과를 버린 경우 null입니다.
  Future<String?> toggle() async {
    if (isSaving || isLoading || !hasLoadedStatus) return null;
    final snap = _snapshot();
    if (!snap.ok) return null;
    final before = isFavorite;
    final failMessage = before ? '즐겨찾기 해제에 실패했습니다.' : '즐겨찾기 등록에 실패했습니다.';
    isSaving = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      // timeout이어도 같은 POST를 자동으로 다시 보내지 않습니다.
      if (before) {
        await favoriteApi.deleteFavorite(movieId: movieId);
      } else {
        await favoriteApi.addFavorite(movieId: movieId);
      }
      if (_isStale(snap.generation)) return null;
      isFavorite = !before;
    } on DioException catch (error) {
      if (_isStale(snap.generation)) return null;
      final code = apiErrorCode(error);
      if (isSessionExpiredError(error)) {
        await onSessionExpired();
        return null;
      }
      if (code == 'FAVORITE409_1' || code == 'FAVORITE404_1') {
        // 이미 등록(409)이거나 이미 해제(404)이면 서버의 현재 여부로 화면을 맞춥니다.
        await _syncFromServer(snap.generation, before);
      } else if (code == 'MEMBER404_1') {
        // 즐겨찾기 없음(FAVORITE404_1)과 다른 회원 없음 오류입니다.
        isFavorite = before;
        errorMessage = '회원 정보를 찾을 수 없습니다. 다시 로그인해 주세요.';
      } else {
        isFavorite = before;
        errorMessage = failMessage;
      }
    } catch (_) {
      if (_isStale(snap.generation)) return null;
      isFavorite = before;
      errorMessage = failMessage;
    } finally {
      if (!_isStale(snap.generation)) {
        isSaving = false;
        notifyIfAlive();
      }
    }
    if (_isStale(snap.generation)) return null;
    return errorMessage ?? (isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 삭제했습니다.');
  }

  Future<void> _syncFromServer(int generation, bool before) async {
    try {
      final synced = await favoriteApi.checkFavorite(movieId: movieId);
      if (_isStale(generation)) return;
      isFavorite = synced.isFavorite;
      errorMessage = null;
    } catch (error) {
      if (_isStale(generation)) return;
      if (isSessionExpiredError(error)) {
        await onSessionExpired();
        return;
      }
      isFavorite = before;
      errorMessage = '서버 상태를 다시 확인하지 못했습니다.';
    }
  }
}
