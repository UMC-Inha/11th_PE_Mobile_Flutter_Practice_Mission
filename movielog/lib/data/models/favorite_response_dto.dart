/// 즐겨찾기 한 건. 등록 응답(`result`)과 내 목록(`result` 배열)의 한 줄이 같은 모양이다.
///
/// 제목·포스터는 없다. `movieId`(TMDB id)로 TMDB에서 가져와 합친다.
class FavoriteResponseDto {
  const FavoriteResponseDto({
    required this.favoriteId,
    required this.movieId,
    required this.createdAt,
  });

  factory FavoriteResponseDto.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('FavoriteResponseDto must be a JSON object.');
    }
    return FavoriteResponseDto(
      favoriteId: (json['favoriteId'] as num).toInt(),
      movieId: (json['movieId'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final int favoriteId;

  /// TMDB 영화 id. 즐겨찾기 조회·해제 경로에도 favoriteId가 아니라 이 값을 쓴다.
  final int movieId;
  final DateTime createdAt;
}
