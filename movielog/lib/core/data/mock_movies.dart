/// 3주차 Mock Movie 데이터.
///
/// 홈, 영화 목록, 영화 상세가 모두 이 파일의 같은 데이터를 사용한다.
/// 실제 서버와 연결하지 않는다.
class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.genre,
    required this.year,
    required this.posterPath,
    required this.runtimeMinutes,
    required this.averageRating,
    required this.overview,
  });

  final String id;
  final String title;
  final String genre;
  final int year;
  final String posterPath;
  final int runtimeMinutes;
  final double averageRating;
  final String overview;
}

const movieGenres = ['로맨스', '액션', 'SF', '드라마', '스릴러', '판타지'];

const mockMovies = <Movie>[
  Movie(
    id: 'under-the-starlight',
    title: '별빛 아래 우리',
    genre: '로맨스',
    year: 2026,
    posterPath: 'assets/images/posters/hero_under_the_starlight.jpg',
    runtimeMinutes: 118,
    averageRating: 4.5,
    overview: '별이 가장 잘 보이는 밤, 서로 다른 꿈을 가진 두 사람이 한 망원경 앞에서 만난다.',
  ),
  Movie(
    id: 'mission-improbable',
    title: '미션: 임프로버블',
    genre: '액션',
    year: 2025,
    posterPath: 'assets/images/posters/poster_abyss_walker.jpg',
    runtimeMinutes: 126,
    averageRating: 4.1,
    overview: '돌아온 요원 맥스 스틸러. 이번 임무는 폭발보다 웃음이 더 크게 터진다.',
  ),
  Movie(
    id: 'echoes-of-the-void',
    title: '공허의 메아리',
    genre: 'SF',
    year: 2024,
    posterPath: 'assets/images/posters/poster_echoes_of_the_void.jpg',
    runtimeMinutes: 124,
    averageRating: 3.9,
    overview: '우주 끝에서 돌아온 신호가 20년 전 실종된 동료의 목소리를 담고 있다.',
  ),
  Movie(
    id: 'fourth-afternoon',
    title: '네 번째 오후',
    genre: '드라마',
    year: 2025,
    posterPath: 'assets/images/posters/poster_fourth_afternoon.jpg',
    runtimeMinutes: 104,
    averageRating: 4.3,
    overview: '매주 같은 카페에 모이는 네 친구가 각자의 네 번째 오후를 기억해 낸다.',
  ),
  Movie(
    id: 'night-shadows',
    title: '밤의 그림자',
    genre: '스릴러',
    year: 2026,
    posterPath: 'assets/images/posters/poster_night_shadows.jpg',
    runtimeMinutes: 111,
    averageRating: 4.0,
    overview: '도시의 불이 모두 꺼진 밤, 한 형사가 그림자처럼 사라진 목격자를 쫓는다.',
  ),
  Movie(
    id: 'whispering-woods',
    title: '속삭이는 숲',
    genre: '판타지',
    year: 2024,
    posterPath: 'assets/images/posters/poster_whispering_woods.jpg',
    runtimeMinutes: 99,
    averageRating: 4.2,
    overview: '이름을 부르면 대답하는 숲에서, 소녀는 잃어버린 동생의 목소리를 듣는다.',
  ),
];

/// Route의 movieId로 Mock Movie를 찾는다. 없으면 null.
Movie? findMovieById(String? id) {
  for (final movie in mockMovies) {
    if (movie.id == id) return movie;
  }
  return null;
}

/// 선택한 장르로 목록을 거른다. 선택이 비어 있으면 전체 목록.
List<Movie> filterMoviesByGenres(Set<String> genres) {
  if (genres.isEmpty) return mockMovies;
  return mockMovies.where((movie) => genres.contains(movie.genre)).toList();
}
