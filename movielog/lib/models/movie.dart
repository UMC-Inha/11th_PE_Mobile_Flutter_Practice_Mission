import 'package:flutter/widgets.dart';

/// 홈·목록·상세 화면이 함께 사용하는 영화 Mock 모델입니다.
class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.genre,
    required this.genres,
    required this.year,
    required this.runtime,
    required this.posterAsset,
    this.posterAlignment = Alignment.center,
    required this.averageRating,
    required this.ratingCount,
    required this.tags,
    required this.synopsis,
  });

  final int id;
  final String title;

  /// 목록 카드와 장르 필터에 사용하는 대표 장르
  final String genre;

  /// 상세 화면에 '로맨스/드라마'처럼 표시할 전체 장르
  final List<String> genres;
  final int year;

  /// 상영 시간(분)
  final int runtime;
  final String posterAsset;

  /// 가로로 긴 이미지를 세로 카드에 잘라 보여줄 때 기준 위치
  final Alignment posterAlignment;

  /// 서버에서 받아온다고 가정한 평균 평점과 평가 수 (Mock)
  final double averageRating;
  final int ratingCount;

  /// 상세 화면의 키워드 Chip
  final List<String> tags;
  final String synopsis;
}

const movies = [
  Movie(
    id: 1,
    title: '별빛 아래 우리',
    genre: '드라마',
    genres: ['로맨스', '드라마'],
    year: 2024,
    runtime: 124,
    posterAsset: 'assets/images/posters/hero_under_the_starlight.jpg',
    posterAlignment: Alignment(0.55, 0),
    averageRating: 4.5,
    ratingCount: 1245,
    tags: ['로맨스', '드라마', '감동적인'],
    synopsis: '바쁜 현대 사회 속에서 서로의 존재를 잊고 살아가던 두 남녀가 우연한 계기로 '
        '작은 천문대에서 만나게 됩니다. 매일 밤 별을 관측하며 서로의 상처를 치유하고, '
        '잊고 있던 꿈과 사랑을 다시금 깨닫게 되는 따뜻한 이야기입니다.\n\n'
        '과거의 아픔으로 인해 사람에게 마음을 열지 못하던 여주인공은, 별자리처럼 '
        '변함없는 모습으로 자신을 기다려주는 남주인공을 통해 서서히 마음의 문을 열게 '
        '됩니다. 하지만 두 사람 앞에 놓인 현실적인 장벽들은 그들의 관계를 시험하게 되는데...\n\n'
        '별이 쏟아지는 밤하늘 아래, 그들이 나눈 조용한 약속들은 과연 영원할 수 있을까요? '
        '눈부신 영상미와 감성적인 OST가 어우러져 깊은 여운을 남기는 올 겨울 최고의 로맨스 영화.\n\n'
        '잔잔한 감동과 함께 삶의 의미를 다시 한번 되돌아보게 만드는 수작입니다.',
  ),
  Movie(
    id: 2,
    title: '우주의 끝에서',
    genre: 'SF',
    genres: ['SF', '어드벤처'],
    year: 2024,
    runtime: 132,
    posterAsset: 'assets/images/posters/poster_echoes_of_the_void.jpg',
    averageRating: 4.2,
    ratingCount: 987,
    tags: ['SF', '우주', '미스터리'],
    synopsis: '은하 끝자락에서 들려오는 정체불명의 신호를 따라 떠난 탐사선. '
        '돌아갈 수 없는 거리에서 홀로 남은 탐사대원은 신호의 진짜 의미를 알게 됩니다.\n\n'
        '광활한 우주와 인간의 고독을 압도적인 스케일로 담아낸 SF 드라마.',
  ),
  Movie(
    id: 3,
    title: '기억의 숲',
    genre: '애니메이션',
    genres: ['애니메이션', '판타지'],
    year: 2024,
    runtime: 109,
    posterAsset: 'assets/images/posters/poster_whispering_woods.jpg',
    averageRating: 4.9,
    ratingCount: 2310,
    tags: ['애니메이션', '판타지', '가족'],
    synopsis: '할머니 댁 뒤편의 숲에서 나무들의 속삭임을 듣게 된 소녀가 '
        '사라져 가는 숲의 기억을 지키기 위한 모험을 시작합니다.\n\n'
        '마법과 우정이 가득한, 온 가족이 함께 보기 좋은 따뜻한 애니메이션.',
  ),
  Movie(
    id: 4,
    title: '밤의 그림자',
    genre: '스릴러',
    genres: ['스릴러', '범죄'],
    year: 2024,
    runtime: 115,
    posterAsset: 'assets/images/posters/poster_night_shadows.jpg',
    averageRating: 3.8,
    ratingCount: 654,
    tags: ['스릴러', '범죄', '긴장감'],
    synopsis: '연쇄 실종 사건을 쫓던 형사가 도시의 밤마다 나타나는 그림자의 정체에 '
        '가까워질수록 자신의 과거와 마주하게 됩니다.\n\n'
        '네온 불빛 아래 숨겨진 진실을 파헤치는 누아르 스릴러.',
  ),
  Movie(
    id: 5,
    title: '미션 임프로버블',
    genre: '코미디',
    genres: ['코미디', '액션'],
    year: 2023,
    runtime: 121,
    posterAsset: 'assets/images/posters/poster_abyss_walker.jpg',
    averageRating: 3.9,
    ratingCount: 1532,
    tags: ['코미디', '액션', '유쾌한'],
    synopsis: '은퇴를 앞둔 허당 첩보요원 맥스가 마지막 임무를 맡게 되면서 벌어지는 '
        '좌충우돌 액션 코미디.\n\n'
        '폭발보다 더 큰 웃음이 터지는, 가볍게 즐기기 좋은 오락 영화.',
  ),
  Movie(
    id: 6,
    title: '네 번째 오후',
    genre: '로맨스',
    genres: ['로맨스', '드라마'],
    year: 2023,
    runtime: 104,
    posterAsset: 'assets/images/posters/poster_fourth_afternoon.jpg',
    averageRating: 4.3,
    ratingCount: 876,
    tags: ['로맨스', '일상', '잔잔한'],
    synopsis: '매주 같은 요일 오후, 같은 카페에서 마주치는 두 사람. '
        '평범한 대화 속에 서로의 마음이 조금씩 가까워집니다.\n\n'
        '올 가을, 당신의 마음을 두드릴 잔잔한 로맨스.',
  ),
];

/// 영화 목록의 장르 Chip에 사용할 장르 목록입니다. ('전체'는 필터 없음)
const allGenreLabel = '전체';
final movieGenres = [
  allGenreLabel,
  ...{for (final movie in movies) movie.genre},
];

Movie? findMovieById(int? id) {
  for (final movie in movies) {
    if (movie.id == id) return movie;
  }
  return null;
}

List<Movie> moviesByGenre(String genre) {
  if (genre == allGenreLabel) return movies;
  return movies.where((movie) => movie.genre == genre).toList();
}

/// 평점이 높은 순서로 정렬한 인기 영화 목록입니다.
List<Movie> get popularMovies =>
    [...movies]..sort((a, b) => b.averageRating.compareTo(a.averageRating));
