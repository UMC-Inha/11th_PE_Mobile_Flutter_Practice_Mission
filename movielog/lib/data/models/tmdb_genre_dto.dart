/// TMDB Genre API의 장르 하나(`id`, `name`)를 표현하는 DTO입니다.
class TmdbGenreDto {
  const TmdbGenreDto({required this.id, required this.name});
  final int id;
  final String name;

  factory TmdbGenreDto.fromJson(Map<String, dynamic> json) {
    return TmdbGenreDto(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
    );
  }
}
