import 'package:dio/dio.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';

/// TMDB와 직접 통신하는 Service Layer.
///
/// HTTP 요청과 JSON → DTO 변환만 한다. 상태를 갖지 않으므로(stateless)
/// 여러 ViewModel이 인스턴스 하나를 함께 쓴다.
/// "인기 5개", "최대 30개", "선택된 장르"는 화면 정책이므로 ViewModel이 정한다.
class TmdbMovieService {
  TmdbMovieService(this._dio);

  final Dio _dio;

  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/movie/popular',
      queryParameters: {'language': 'ko-KR', 'page': page},
    );
    return TmdbMoviePageDto.fromJson(response.data!);
  }

  /// [genreIds]가 비었거나 null이면 `with_genres`를 보내지 않는다(전체).
  /// 여러 개면 OR(`|`)로 이어 "이 중 하나라도 해당하는 영화"를 찾는다.
  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    List<int>? genreIds,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/discover/movie',
      queryParameters: {
        'language': 'ko-KR',
        'page': page,
        'sort_by': 'popularity.desc',
        'include_adult': false,
        'include_video': false,
        if (genreIds != null && genreIds.isNotEmpty)
          'with_genres': withGenresQuery(genreIds),
      },
      cancelToken: cancelToken,
    );
    return TmdbMoviePageDto.fromJson(response.data!);
  }

  Future<List<TmdbGenreDto>> fetchGenres() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/genre/movie/list',
      queryParameters: {'language': 'ko'},
    );
    final genres = response.data?['genres'] as List<dynamic>? ?? const [];
    return genres
        .map((item) => TmdbGenreDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 상세 화면을 주소로 바로 열거나, 자체 백엔드 평점의 movieId로 영화를 찾을 때 쓴다.
  Future<TmdbMovieDto> fetchMovie(int movieId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/movie/$movieId',
      queryParameters: {'language': 'ko-KR'},
    );
    return TmdbMovieDto.fromJson(response.data!);
  }
}

/// [28, 12] → "28|12"
String withGenresQuery(List<int> genreIds) => genreIds.join('|');
