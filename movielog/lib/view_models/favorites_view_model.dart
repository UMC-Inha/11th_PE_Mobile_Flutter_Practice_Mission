import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/core/utils/map_bounded.dart';
import 'package:movielog/core/utils/safe_notify.dart';
import 'package:movielog/data/models/favorite_list_item.dart';
import 'package:movielog/data/services/favorite_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/load_error_message.dart';
import 'package:movielog/view_models/load_phase.dart';

/// "내 즐겨찾기" 화면 ViewModel.
///
/// 즐겨찾기 응답(MovieLog)에는 제목·포스터가 없다. 그래서 [refresh]는
/// **세션 확인 → 목록 조회 → TMDB 영화 정보 보충 → 상태 결정** 순서로 일한다.
///
/// - 영화 정보 보충은 [mapBounded]로 한 번에 최대 [enrichmentConcurrency]개만 요청한다.
/// - 영화 한 건의 정보 조회가 실패해도 목록 전체를 실패로 만들지 않는다. 그 카드만
///   [FavoriteListItem.movie] == null(placeholder)이 되고, [retryMovie]로 그 카드만 다시 조회한다.
/// - 이 ViewModel은 **한 로그인 세션 전용**이다. 이전 세션의 늦은 응답은 [SessionGuard]로 버리고,
///   로그아웃·계정 전환 때는 Route의 `ValueKey`가 ViewModel째로 새로 만든다.
///   사용자별 즐겨찾기([items])와 공개 영화 정보(TMDB)는 같은 Map에 섞지 않고 한 카드 안에서만 합친다.
class FavoritesViewModel extends ChangeNotifier with SafeNotify {
  FavoritesViewModel({
    required this.favoriteApi,
    required this.tmdbApi,
    required this.auth,
    required this.sessionGuard,
    required this.accountId,
    this.enrichmentConcurrency = 5,
  });

  final FavoriteApiService favoriteApi;
  final TmdbMovieService tmdbApi;
  final AuthViewModel auth;
  final SessionGuard sessionGuard;
  final String accountId;

  /// TMDB 영화 정보를 동시에 요청하는 최대 개수.
  final int enrichmentConcurrency;

  LoadPhase phase = LoadPhase.idle;
  List<FavoriteListItem> items = const [];
  String? errorMessage;

  /// 영화 정보를 다시 조회하는 중인 movieId(그 카드의 버튼만 로딩으로 바꾼다).
  final Set<int> retryingMovieIds = {};

  int _refreshGeneration = 0;

  bool _isStale(int sessionGeneration, int refreshGeneration) =>
      isDisposed ||
      !sessionGuard.isCurrent(sessionGeneration, accountId) ||
      refreshGeneration != _refreshGeneration;

  /// 즐겨찾기 목록을 다시 조회하고 TMDB 영화 정보를 최대 5개씩 보충한다.
  Future<void> refresh() async {
    final sessionGeneration = sessionGuard.generation;
    if (isDisposed || !sessionGuard.isCurrent(sessionGeneration, accountId)) {
      return;
    }
    final authVersion = auth.sessionVersion;
    final refreshGeneration = ++_refreshGeneration;
    phase = LoadPhase.loading;
    errorMessage = null;
    retryingMovieIds.clear();
    notifyIfAlive();
    try {
      final favorites = await favoriteApi.fetchMyFavorites();
      if (_isStale(sessionGeneration, refreshGeneration)) return;
      final enriched = await mapBounded(favorites, enrichmentConcurrency, (
        favorite,
      ) async {
        try {
          final movie = await tmdbApi.fetchMovie(favorite.movieId);
          return FavoriteListItem(favorite: favorite, movie: movie);
        } catch (_) {
          // 이 한 건만 placeholder가 된다. 다른 카드와 목록 전체는 영향받지 않는다.
          return FavoriteListItem(
            favorite: favorite,
            errorMessage: '영화 정보를 불러오지 못했어요.',
          );
        }
      });
      if (_isStale(sessionGeneration, refreshGeneration)) return;
      items = enriched;
      phase = items.isEmpty ? LoadPhase.empty : LoadPhase.ready;
    } on DioException catch (error) {
      if (_isStale(sessionGeneration, refreshGeneration)) return;
      if (isSessionExpiredCode(apiErrorCode(error))) {
        // 현재 세션이 만료됐다. 한 번만 정리하면 Router가 로그인 화면으로 보낸다.
        await auth.expireSession(forVersion: authVersion);
        return;
      }
      phase = LoadPhase.error;
      errorMessage = loadErrorMessage(
        error,
        fallback: '내 즐겨찾기를 불러오지 못했어요. 다시 시도해 주세요.',
      );
    } catch (_) {
      if (_isStale(sessionGeneration, refreshGeneration)) return;
      phase = LoadPhase.error;
      errorMessage = '내 즐겨찾기를 불러오지 못했어요. 다시 시도해 주세요.';
    } finally {
      if (!_isStale(sessionGeneration, refreshGeneration)) notifyIfAlive();
    }
  }

  /// 영화 정보를 못 가져온 카드 한 장만 TMDB에서 다시 조회한다. 다른 카드는 그대로 둔다.
  Future<void> retryMovie(int movieId) async {
    final sessionGeneration = sessionGuard.generation;
    if (isDisposed || !sessionGuard.isCurrent(sessionGeneration, accountId)) {
      return;
    }
    if (!retryingMovieIds.add(movieId)) return; // 이미 다시 조회 중
    final refreshGeneration = _refreshGeneration;
    notifyIfAlive();
    FavoriteListItem Function(FavoriteListItem item) change;
    try {
      final movie = await tmdbApi.fetchMovie(movieId);
      change = (item) => item.withMovie(movie);
    } catch (_) {
      change = (item) => item.withError('영화 정보를 불러오지 못했어요.');
    }
    if (_isStale(sessionGeneration, refreshGeneration)) return;
    items = [
      for (final item in items)
        item.favorite.movieId == movieId ? change(item) : item,
    ];
    retryingMovieIds.remove(movieId);
    notifyIfAlive();
  }
}
