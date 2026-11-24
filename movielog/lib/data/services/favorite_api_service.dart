import 'package:dio/dio.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/favorite_check_dto.dart';
import 'package:movielog/data/models/favorite_response_dto.dart';

/// MovieLog 즐겨찾기 API(`/favorites`). **보호 Client**로만 보낸다.
/// 요청 어디에도 memberId가 없다. 누구의 즐겨찾기인지는 토큰이 알려 준다.
///
/// 경로에는 favoriteId가 아니라 TMDB `movieId`를 쓴다(상세 화면이 가진 값이 movieId다).
/// 오류는 DioException 그대로 던진다. 전용 예외를 새로 만들지 않고 호출 쪽이 `apiErrorCode`로 구분한다.
class FavoriteApiService {
  FavoriteApiService(this._authDio);

  final Dio _authDio;

  /// 등록: 201, `result`에 [FavoriteResponseDto].
  Future<FavoriteResponseDto> addFavorite({required int movieId}) async {
    final response = await _authDio.post<Object?>(
      '/favorites',
      data: {'movieId': movieId},
    );
    final result = _parse(response.data, FavoriteResponseDto.fromJson);
    if (result == null) throw StateError('즐겨찾기 등록 result가 없습니다.');
    return result;
  }

  /// 내 목록: 200, `result`가 배열(최신 등록순). 없으면 빈 배열.
  Future<List<FavoriteResponseDto>> fetchMyFavorites() async {
    final response = await _authDio.get<Object?>('/favorites');
    final result = _parse<List<FavoriteResponseDto>>(response.data, (value) {
      if (value is! List) throw const FormatException('result must be a list.');
      return value.map(FavoriteResponseDto.fromJson).toList();
    });
    return result ?? const [];
  }

  /// 특정 영화의 즐겨찾기 여부: 응답에 movieId가 없어서 요청한 값을 함께 넘겨 파싱한다.
  Future<FavoriteCheckDto> checkFavorite({required int movieId}) async {
    final response = await _authDio.get<Object?>('/favorites/$movieId');
    final result = _parse(
      response.data,
      (value) => FavoriteCheckDto.fromJson(value, movieId: movieId),
    );
    if (result == null) throw StateError('즐겨찾기 여부 result가 없습니다.');
    return result;
  }

  /// 해제: **200**이고 `result`는 null이다(평점 삭제와 달리 본문을 파싱하지 않는다).
  /// 응답이 오면(= DioException이 없으면) 성공이다.
  Future<void> deleteFavorite({required int movieId}) async {
    await _authDio.delete<Object?>('/favorites/$movieId');
  }

  /// 공통 응답 틀의 `result`를 [parseResult]로 바꾼다. 틀이 어긋나면 [StateError].
  T? _parse<T>(Object? data, T Function(Object? value) parseResult) {
    if (data is! Map<String, dynamic>) {
      throw StateError('즐겨찾기 응답 형식이 올바르지 않습니다.');
    }
    return CommonResponse<T>.fromJson(data, parseResult).result;
  }
}
