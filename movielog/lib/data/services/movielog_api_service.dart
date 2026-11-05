import 'package:dio/dio.dart';
import 'package:movielog/data/models/movielog_dtos.dart';

/// MovieLog 자체 백엔드(회원·평점) Service. TMDB Service와 Client를 공유하지 않는다.
class MovieLogApiService {
  MovieLogApiService(this._dio);

  final Dio _dio;

  Future<AvailabilityDto> checkNickname(String nickname) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/members/nickname/${Uri.encodeComponent(nickname)}',
    );
    return AvailabilityDto.fromJson(response.data!);
  }

  Future<AvailabilityDto> checkEmail(String email) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/members/email/${Uri.encodeComponent(email)}',
    );
    return AvailabilityDto.fromJson(response.data!);
  }

  Future<List<MemberRatingDto>> fetchMemberRatings(int memberId) async {
    final response = await _dio.get<List<dynamic>>(
      '/members/$memberId/ratings',
    );
    return (response.data ?? const [])
        .map((item) => MemberRatingDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
