import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/core/utils/safe_notify.dart';
import 'package:movielog/data/services/favorite_api_service.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/load_error_message.dart';

/// 등록·해제 한 번의 결과. 화면이 Snackbar 문구를 고르는 데 쓴다.
enum FavoriteToggleResult {
  /// 서버가 등록을 확인했다.
  added,

  /// 서버가 해제를 확인했다.
  removed,

  /// 등록하려 했는데 이미 등록돼 있었다(409). 서버의 현재 값으로 맞췄다.
  alreadyAdded,

  /// 해제하려 했는데 이미 없었다(404). 서버의 현재 값으로 맞췄다.
  alreadyRemoved,

  /// 실패했다. [FavoriteDetailViewModel.errorMessage]에 이유가 있고 아이콘은 그대로다.
  failed,

  /// 아무것도 하지 않았다(요청 중·아직 여부를 모름·이미 끝난 세션·세션 만료 처리).
  ignored,
}

/// 영화 상세의 즐겨찾기 버튼 상태.
///
/// - [isLoading]: 상세에 들어와 서버의 현재 여부를 처음 조회하는 중
/// - [isSaving]: 등록·해제 요청 중
/// - [isFavorite]: **서버가 확인한** 값. 응답을 기다리지 않고 먼저 바꾸는 optimistic update는 하지 않는다.
/// - [errorMessage]: 마지막 실패 안내
///
/// 오류 처리
/// - `FAVORITE409_1`(이미 등록)·`FAVORITE404_1`(이미 없음): POST/DELETE를 반복하지 않고
///   `GET /favorites/{movieId}`로 현재 여부를 맞춘다.
/// - 응답이 없는 실패(timeout 포함): 같은 POST를 **자동으로 다시 보내지 않는다.** 서버에서는
///   성공했을 수 있어서, 사용자가 다시 누르면 409→GET으로 맞춰진다.
/// - `AUTH401_2/3/4`: 현재 세션을 한 번만 정리한다. 이전 로그인 세션에서 늦게 온 401은 무시한다
///   ([SessionGuard]로 판정). 403·네트워크 실패는 로그아웃하지 않는다.
class FavoriteDetailViewModel extends ChangeNotifier with SafeNotify {
  FavoriteDetailViewModel({
    required this.movieId,
    required this.favoriteApi,
    required this.auth,
    required this.sessionGuard,
    required this.accountId,
  });

  /// 상세 화면의 TMDB 영화 ID. 즐겨찾기 경로에는 favoriteId가 아니라 이 값을 쓴다.
  final int movieId;
  final FavoriteApiService favoriteApi;
  final AuthViewModel auth;
  final SessionGuard sessionGuard;

  /// 이 ViewModel이 만들어진 세션의 계정(email). 화면 쪽에서 세션을 구분하는 데만 쓴다.
  final String accountId;

  bool isFavorite = false;

  /// 서버에서 여부를 한 번이라도 받았는가. 받기 전에는 버튼을 눌러도 등록·해제하지 않는다.
  bool hasLoadedStatus = false;
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  /// 요청을 보내는 시점의 세션. 응답이 돌아왔을 때 [_isCurrent]로 같은 세션인지 확인한다.
  ({int generation, int authVersion, bool ok}) _snapshot() {
    final generation = sessionGuard.generation;
    return (
      generation: generation,
      authVersion: auth.sessionVersion,
      ok: sessionGuard.isCurrent(generation, accountId) && !isDisposed,
    );
  }

  bool _isCurrent(({int generation, int authVersion, bool ok}) snap) =>
      !isDisposed && sessionGuard.isCurrent(snap.generation, accountId);

  /// 세션 만료 code면 현재 세션을 한 번 정리하고 true. 호출 전에 [_isCurrent]를 확인해,
  /// 이전 세션의 늦은 401이 새 세션을 지우지 않게 한다.
  Future<bool> _expireIfNeeded(
    DioException error,
    ({int generation, int authVersion, bool ok}) snap,
  ) async {
    if (!isSessionExpiredCode(apiErrorCode(error))) return false;
    await auth.expireSession(forVersion: snap.authVersion);
    return true;
  }

  /// 상세 화면이 만들어질 때 한 번 부른다(build에서 부르지 않는다). 서버의 현재 여부를 받아 온다.
  Future<void> load() async {
    if (isLoading || isSaving) return;
    final snap = _snapshot();
    if (!snap.ok) return;
    isLoading = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      final result = await favoriteApi.checkFavorite(movieId: movieId);
      if (!_isCurrent(snap)) return;
      isFavorite = result.isFavorite;
      hasLoadedStatus = true;
    } on DioException catch (error) {
      if (!_isCurrent(snap)) return;
      if (await _expireIfNeeded(error, snap)) return;
      errorMessage = '즐겨찾기 여부를 확인하지 못했어요.';
    } catch (_) {
      if (!_isCurrent(snap)) return;
      errorMessage = '즐겨찾기 여부를 확인하지 못했어요.';
    } finally {
      if (_isCurrent(snap)) {
        isLoading = false;
        notifyIfAlive();
      }
    }
  }

  /// 서버 성공을 확인한 뒤에 북마크 상태를 바꾼다. 요청 중에는 중복 탭을 막는다.
  Future<FavoriteToggleResult> toggle() async {
    if (isSaving || isLoading || !hasLoadedStatus) {
      return FavoriteToggleResult.ignored;
    }
    final snap = _snapshot();
    if (!snap.ok) return FavoriteToggleResult.ignored;
    final before = isFavorite;
    isSaving = true;
    errorMessage = null;
    notifyIfAlive();
    var result = FavoriteToggleResult.failed;
    try {
      if (before) {
        await favoriteApi.deleteFavorite(movieId: movieId);
        if (!_isCurrent(snap)) return FavoriteToggleResult.ignored;
        isFavorite = false;
        result = FavoriteToggleResult.removed;
      } else {
        await favoriteApi.addFavorite(movieId: movieId);
        if (!_isCurrent(snap)) return FavoriteToggleResult.ignored;
        isFavorite = true;
        result = FavoriteToggleResult.added;
      }
    } on DioException catch (error) {
      if (!_isCurrent(snap)) return FavoriteToggleResult.ignored;
      if (await _expireIfNeeded(error, snap)) {
        return FavoriteToggleResult.ignored;
      }
      final code = apiErrorCode(error);
      if (code == 'FAVORITE409_1' || code == 'FAVORITE404_1') {
        // 이미 등록(409)이거나 이미 없음(404)이면 같은 요청을 반복하지 않고
        // 서버의 현재 여부로 화면을 맞춘다.
        result = await _syncFromServer(snap, before: before);
        if (!_isCurrent(snap)) return FavoriteToggleResult.ignored;
      } else {
        isFavorite = before;
        errorMessage = _failureText(error, wasFavorite: before);
      }
    } catch (_) {
      if (!_isCurrent(snap)) return FavoriteToggleResult.ignored;
      isFavorite = before;
      errorMessage = _failureText(null, wasFavorite: before);
    } finally {
      if (_isCurrent(snap)) {
        isSaving = false;
        notifyIfAlive();
      }
    }
    return result;
  }

  /// 409·404 뒤에 서버의 현재 여부를 GET으로 받아 [isFavorite]를 맞춘다.
  Future<FavoriteToggleResult> _syncFromServer(
    ({int generation, int authVersion, bool ok}) snap, {
    required bool before,
  }) async {
    try {
      final synced = await favoriteApi.checkFavorite(movieId: movieId);
      if (!_isCurrent(snap)) return FavoriteToggleResult.ignored;
      isFavorite = synced.isFavorite;
      hasLoadedStatus = true;
      return synced.isFavorite
          ? FavoriteToggleResult.alreadyAdded
          : FavoriteToggleResult.alreadyRemoved;
    } on DioException catch (error) {
      if (!_isCurrent(snap)) return FavoriteToggleResult.ignored;
      if (await _expireIfNeeded(error, snap)) {
        return FavoriteToggleResult.ignored;
      }
    } catch (_) {
      if (!_isCurrent(snap)) return FavoriteToggleResult.ignored;
    }
    isFavorite = before;
    errorMessage = '서버 상태를 다시 확인하지 못했어요. 잠시 후 다시 시도해 주세요.';
    return FavoriteToggleResult.failed;
  }

  /// 실패 안내. 응답이 없는 실패(timeout·연결 실패)는 이유를 덧붙인다. 403 등 서버가 거절한
  /// 응답은 로그아웃 사유가 아니므로 같은 문구로 안내만 한다.
  String _failureText(Object? error, {required bool wasFavorite}) {
    final base = wasFavorite ? '즐겨찾기를 해제하지 못했어요.' : '즐겨찾기를 등록하지 못했어요.';
    if (error is DioException && error.type != DioExceptionType.badResponse) {
      return '$base ${loadErrorMessage(error, fallback: '')}'.trim();
    }
    return base;
  }
}
