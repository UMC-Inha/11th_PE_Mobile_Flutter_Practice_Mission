import 'package:dio/dio.dart';

import 'package:movielog/data/models/favorite_check_dto.dart';
import 'package:movielog/data/models/favorite_response_dto.dart';
import 'package:movielog/data/services/favorite_api_service.dart';

/// 서버 대신 메모리에 즐겨찾기를 보관하는 테스트용 Service입니다.
class FakeFavoriteApiService extends FavoriteApiService {
  FakeFavoriteApiService({Set<int>? initial})
    : favorites = {...?initial},
      super(Dio());

  /// 현재 즐겨찾기한 movieId입니다. (서버 상태)
  final Set<int> favorites;

  /// 다음 요청 하나를 이 code/status의 오류로 실패시킵니다.
  String? nextErrorCode;
  int nextErrorStatus = 400;

  /// 다음 요청 하나를 네트워크 오류로 실패시킵니다.
  bool nextNetworkError = false;

  /// 등록·해제 요청이 서버에서는 반영된 뒤 오류를 돌려줍니다. (timeout 재현)
  bool applyBeforeError = false;

  final requests = <String>[];
  int _nextFavoriteId = 1;

  Future<void> _maybeFail(String path) async {
    await Future<void>.delayed(Duration.zero);
    final options = RequestOptions(path: path);
    if (nextNetworkError) {
      nextNetworkError = false;
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    final code = nextErrorCode;
    if (code != null) {
      nextErrorCode = null;
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: options,
          statusCode: nextErrorStatus,
          data: {
            'isSuccess': false,
            'code': code,
            'message': code,
            'result': null,
          },
        ),
      );
    }
  }

  @override
  Future<FavoriteResponseDto> addFavorite({required int movieId}) async {
    requests.add('POST /v8/favorites $movieId');
    if (applyBeforeError) favorites.add(movieId);
    await _maybeFail('/v8/favorites');
    favorites.add(movieId);
    return FavoriteResponseDto(
      favoriteId: _nextFavoriteId++,
      movieId: movieId,
      createdAt: DateTime(2026),
    );
  }

  @override
  Future<List<FavoriteResponseDto>> fetchMyFavorites() async {
    requests.add('GET /v8/favorites');
    await _maybeFail('/v8/favorites');
    return [
      for (final id in favorites)
        FavoriteResponseDto(
          favoriteId: id,
          movieId: id,
          createdAt: DateTime(2026),
        ),
    ];
  }

  @override
  Future<FavoriteCheckDto> checkFavorite({required int movieId}) async {
    requests.add('GET /v8/favorites/$movieId');
    await _maybeFail('/v8/favorites/$movieId');
    return FavoriteCheckDto(
      movieId: movieId,
      isFavorite: favorites.contains(movieId),
    );
  }

  @override
  Future<void> deleteFavorite({required int movieId}) async {
    requests.add('DELETE /v8/favorites/$movieId');
    if (applyBeforeError) favorites.remove(movieId);
    await _maybeFail('/v8/favorites/$movieId');
    favorites.remove(movieId);
  }
}
