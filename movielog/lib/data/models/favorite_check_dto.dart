/// `GET /favorites/{movieId}`의 결과. 서버 응답에는 `isFavorite`만 있고 movieId가 없다.
class FavoriteCheckDto {
  const FavoriteCheckDto({required this.movieId, required this.isFavorite});

  /// 응답에 movieId가 없어서, 요청에 쓴 movieId를 [movieId] 인자로 따로 받는다.
  factory FavoriteCheckDto.fromJson(Object? json, {required int movieId}) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('FavoriteCheckDto must be a JSON object.');
    }
    final value = json['isFavorite'];
    if (value is! bool) {
      throw const FormatException('isFavorite must be a boolean.');
    }
    return FavoriteCheckDto(movieId: movieId, isFavorite: value);
  }

  final int movieId;
  final bool isFavorite;
}
