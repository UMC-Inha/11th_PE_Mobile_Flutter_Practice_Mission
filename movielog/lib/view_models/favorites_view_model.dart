import 'package:flutter/foundation.dart';

import '../core/session/session_guard.dart';
import '../core/utils/map_bounded.dart';
import '../core/utils/safe_notify.dart';
import '../data/models/favorite_list_item.dart';
import '../data/models/favorite_response_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/favorite_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'favorite_detail_view_model.dart' show isSessionExpiredError;
import 'load_phase.dart';

/// 마이페이지 "내 즐겨찾기" 화면의 상태를 관리합니다.
/// 즐겨찾기 목록(MovieLog)과 영화 정보(TMDB)를 movieId로 합쳐 카드 목록을 만듭니다.
class FavoritesViewModel extends ChangeNotifier with SafeNotify {
  FavoritesViewModel({
    required this.favoriteApi,
    required this.tmdbApi,
    required this.sessionGuard,
    required this.accountId,
    required this.onSessionExpired,
    this.enrichmentConcurrency = 5,
  });

  final FavoriteApiService favoriteApi;
  final TmdbMovieService tmdbApi;
  final SessionGuard sessionGuard;
  final String accountId;
  final Future<void> Function() onSessionExpired;
  final int enrichmentConcurrency;

  static const movieErrorMessage = '영화 정보를 불러오지 못했습니다.';

  LoadPhase phase = LoadPhase.idle;
  List<FavoriteListItem> items = const [];
  String? errorMessage;
  int _refreshGeneration = 0;

  /// movieId → TMDB 공개 영화 정보입니다. 사용자별 즐겨찾기 상태와 따로 보관합니다.
  final Map<int, TmdbMovieDto> _movieById = {};

  /// 영화 정보를 가져오지 못한 카드가 있는지 여부입니다.
  bool get hasMissingMovie => items.any((item) => !item.hasMovie);

  bool _isStale(int sessionGeneration, int refreshGeneration) =>
      !sessionGuard.isCurrent(sessionGeneration, accountId) ||
      refreshGeneration != _refreshGeneration ||
      isDisposed;

  // 즐겨찾기 목록을 다시 조회하고 TMDB 영화 정보를 최대 5개씩 보충합니다.
  Future<void> refresh() async {
    final sessionGeneration = sessionGuard.generation;
    if (!sessionGuard.isCurrent(sessionGeneration, accountId) || isDisposed) {
      return;
    }
    final refreshGeneration = ++_refreshGeneration;
    // 이미 목록이 있으면 새로고침 중에도 기존 카드를 지우지 않습니다.
    if (items.isEmpty) phase = LoadPhase.loading;
    errorMessage = null;
    notifyIfAlive();
    try {
      final favorites = await favoriteApi.fetchMyFavorites();
      if (_isStale(sessionGeneration, refreshGeneration)) return;
      final enriched = await mapBounded(
        favorites,
        enrichmentConcurrency,
        _enrich,
      );
      if (_isStale(sessionGeneration, refreshGeneration)) return;
      items = enriched;
      phase = items.isEmpty ? LoadPhase.empty : LoadPhase.ready;
    } catch (error) {
      if (_isStale(sessionGeneration, refreshGeneration)) return;
      if (isSessionExpiredError(error)) {
        await onSessionExpired();
        return;
      }
      items = const [];
      phase = LoadPhase.error;
      errorMessage = '내 즐겨찾기 목록을 불러오지 못했습니다.';
    } finally {
      if (!_isStale(sessionGeneration, refreshGeneration)) notifyIfAlive();
    }
  }

  /// 카드 하나의 영화 정보를 가져옵니다. 실패해도 예외를 던지지 않고 실패 카드로 바꿉니다.
  Future<FavoriteListItem> _enrich(FavoriteResponseDto favorite) async {
    final cached = _movieById[favorite.movieId];
    if (cached != null) {
      return FavoriteListItem(favorite: favorite, movie: cached);
    }
    try {
      final movie = await tmdbApi.fetchMovieDetail(favorite.movieId);
      _movieById[favorite.movieId] = movie;
      return FavoriteListItem(favorite: favorite, movie: movie);
    } catch (_) {
      return FavoriteListItem(
        favorite: favorite,
        errorMessage: movieErrorMessage,
      );
    }
  }

  /// 영화 정보를 가져오지 못한 카드 하나만 다시 조회합니다. 다른 카드는 그대로 둡니다.
  Future<void> retryMovie(int movieId) async {
    final sessionGeneration = sessionGuard.generation;
    if (!sessionGuard.isCurrent(sessionGeneration, accountId) || isDisposed) {
      return;
    }
    final refreshGeneration = _refreshGeneration;
    final index = items.indexWhere((item) => item.favorite.movieId == movieId);
    if (index < 0 || items[index].hasMovie || items[index].isRetrying) return;

    _replace(
      movieId,
      (item) => FavoriteListItem(favorite: item.favorite, isRetrying: true),
    );
    final result = await _enrich(items[index].favorite);
    // 그 사이 목록 전체를 다시 조회했다면 새 목록을 덮어쓰지 않습니다.
    if (_isStale(sessionGeneration, refreshGeneration)) return;
    _replace(movieId, (_) => result);
  }

  void _replace(
    int movieId,
    FavoriteListItem Function(FavoriteListItem item) update,
  ) {
    items = [
      for (final item in items)
        item.favorite.movieId == movieId ? update(item) : item,
    ];
    notifyIfAlive();
  }
}
