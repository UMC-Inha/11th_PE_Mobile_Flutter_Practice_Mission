# MovieLog — 5주차 TMDB 영화 API와 MVVM·Provider

4주차 Mock Future를 실제 TMDB API로 바꾸고, 화면 코드와 데이터 코드를 MVVM으로 나눴다.
5주차 자체 백엔드(NestJS `movie` 프로젝트)의 닉네임·이메일 중복 체크와 유저별 평점 조회도 화면에 연결했다.

```bash
cp .env.example .env   # TMDB_ACCESS_TOKEN 에 TMDB "API 읽기 액세스 토큰"(긴 값). .env 는 Git 제외
flutter pub get
flutter run -d chrome --web-port 5173   # 자체 백엔드 CORS 허용 출처와 같은 포트
flutter analyze
flutter test                            # 47개, 네트워크를 쓰지 않는다
MOVIELOG_LIVE=1 flutter test test/live   # 실제 TMDB·백엔드로 인증 화면·로그 생성(evidence/week05)
```

## 구조

| 위치 | 하는 일 |
|---|---|
| `core/config/tmdb_config.dart` | `.env` 값 읽기와 누락 검사를 한곳에 |
| `core/network/tmdb_client.dart` | TMDB 전용 Dio(Bearer Token). debug에서만 로그 Interceptor |
| `core/network/movielog_api_client.dart` | 자체 백엔드 전용 Dio. TMDB Token을 싣지 않는다 |
| `core/network/tmdb_logging_interceptor.dart` | 요청·응답·오류 로그, `Authorization`은 `Bearer ***` |
| `data/models/` | `TmdbMovieDto`·`TmdbMoviePageDto`·`TmdbGenreDto`, 자체 API DTO·`CreateRatingRequest` |
| `data/services/` | HTTP + JSON→DTO 변환만. 상태 없음(여러 ViewModel이 공유) |
| `view_models/` | 화면마다 하나. 인기 5개·최대 30개·선택 장르 같은 화면 정책과 Loading/Empty/Error/Success |
| `features/*/presentation` | View. 상태를 그리고 입력을 ViewModel에 넘길 뿐 API·JSON을 모른다 |
| `widgets/tmdb_poster_image.dart` | `poster_path` → URL, null·로드 실패 placeholder |

`MovieLogApp`의 `MultiProvider`가 `MaterialApp.router` 바깥에서 Service를 공유하고,
각 GoRoute의 `ChangeNotifierProvider`가 화면별 ViewModel을 만들고 dispose한다.

## 동작

- 홈: Popular 첫 페이지 `take(5)`. 요청은 ViewModel 생성 때 한 번.
- 영화: Genre API로 Chip, Discover page 1부터 TMDB `id`를 Map key로 중복 없이 최대 30개(한 페이지 개수를 코드에 박지 않음).
- 장르 선택 → `with_genres`로 page 1부터 재요청. "전체"는 `with_genres` 없음. 요청 중엔 Chip·필터 비활성.
- BottomSheet 다중 선택 → `List<int>` → `with_genres=28|12`(OR).
- Pull to Refresh: 기존 목록을 둔 채 page 1부터, Loading 중엔 제스처 무시.
- 실패: 최근 목록이 있으면 비우지 않고 재시도 Dialog(취소/다시 시도), 없으면 Error 화면.
- 늦게 온 응답은 request version으로 버린다. dispose 뒤 notify 없음.
- 상세 Route `/movies/{TMDB id}`. 평점 Dialog(1~5 정수) → `CreateRatingRequest(movieId: TMDB id)`.
- 회원가입: 닉네임(2~12자)·이메일 `중복 확인` → `GET /members/nickname|email/...`. 확인한 값 그대로여야 가입 버튼이 켜진다.
- 마이페이지: `GET /members/1/ratings`(로그인 전이라 시드 회원 1번) + movieId로 TMDB 제목·포스터.
- 장르·정렬 저장 키는 `selected_genre_ids`(TMDB ID)·`movie_sort`. 4주차 이름 값은 읽지 않는다.

## 검증 자료 (`evidence/week05`)

- `web-signup-duplicate-check.jpg`, `web-my-ratings.jpg`: 실제 Chrome의 MovieLog 웹(5173)이 실제 NestJS 서버(3000)를 CORS 허용 상태로 호출한 화면
- `network-failure-log.txt`: 실제 TMDB에 잘못된 Token → 401, URL·오류는 남고 Token 원문은 없음, release 조건에선 0줄
- `12_empty_fixture.png`, `13_poster_placeholder_fixture.png`: 가짜 응답으로 만든 Empty·포스터 없음/로드 실패
- `01~11_*.png`, `network-log.txt`: `test/live/live_evidence_test.dart`가 실제 TMDB 응답으로 만든 화면(Token 필요)
