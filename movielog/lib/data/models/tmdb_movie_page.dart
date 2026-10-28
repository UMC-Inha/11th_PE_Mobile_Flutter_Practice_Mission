import 'package:movielog/data/models/tmdb_movie_dto.dart';

/// Popular·Discover 공통 페이지 응답.
/// 영화 배열과 page·total_pages를 함께 묶어야 다음 페이지 요청 여부와
/// 최대 30개 수집의 종료 조건을 판단할 수 있다.
class TmdbMoviePageDto {
  const TmdbMoviePageDto({
    required this.page,
    required this.results,
    required this.totalPages,
    required this.totalResults,
  });

  final int page;
  final List<TmdbMovieDto> results;
  final int totalPages;

  /// 전체 탐색 결과 개수. 이번에 모두 내려받는다는 뜻이 아니다.
  final int totalResults;

  factory TmdbMoviePageDto.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'] as List<dynamic>? ?? const [];

    return TmdbMoviePageDto(
      page: (json['page'] as num? ?? 1).toInt(),
      results: rawResults
          .map((item) => TmdbMovieDto.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalPages: (json['total_pages'] as num? ?? 0).toInt(),
      totalResults: (json['total_results'] as num? ?? 0).toInt(),
    );
  }
}
