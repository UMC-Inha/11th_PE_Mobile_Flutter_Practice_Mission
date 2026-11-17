/// Genre API가 돌려준 공식 장르. 이름을 임의로 쓰지 않고 이 id/name을 그대로 쓴다.
class TmdbGenreDto {
  const TmdbGenreDto({required this.id, required this.name});

  final int id;
  final String name;

  factory TmdbGenreDto.fromJson(Map<String, dynamic> json) {
    return TmdbGenreDto(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '장르 ${json['id']}',
    );
  }
}
