import 'package:dio/dio.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/movie_record_models.dart';

/// 평점과 즐겨찾기를 한 번에 저장하는 `POST /movie-records`. **보호 Client**로만 보낸다.
///
/// 서버가 둘을 한 번에 처리한다. 즐겨찾기가 이미 있으면(`FAVORITE409_1`) 평점도 저장되지 않는다.
/// 오류는 DioException 그대로 던지고 호출 쪽이 `apiErrorCode`로 구분한다.
class MovieRecordApiService {
  MovieRecordApiService(this._authDio);

  final Dio _authDio;

  Future<MovieRecordResponseDto> createRecord(
    CreateMovieRecordRequest request,
  ) async {
    final response = await _authDio.post<Object?>(
      '/movie-records',
      data: request.toJson(),
    );
    if (response.statusCode != 201) {
      throw StateError('예상하지 못한 영화 기록 응답: ${response.statusCode}');
    }
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('영화 기록 응답 형식이 올바르지 않습니다.');
    }
    final result = CommonResponse<MovieRecordResponseDto>.fromJson(
      data,
      MovieRecordResponseDto.fromJson,
    ).result;
    if (result == null) throw StateError('영화 기록 result가 없습니다.');
    return result;
  }
}
