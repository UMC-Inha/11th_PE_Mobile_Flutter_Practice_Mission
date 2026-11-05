# MovieLog — 6주차 중복 확인 연동과 평점 조회 (5주차 TMDB 영화 API와 MVVM·Provider 위에)

4주차 Mock Future를 실제 TMDB API로 바꾸고, 화면 코드와 데이터 코드를 MVVM으로 나눴다.
5주차 자체 백엔드(NestJS `movie` 프로젝트)의 닉네임·이메일 중복 체크와 유저별 평점 조회도 화면에 연결했다.
6주차에는 공용 `MovieLogButton`을 만들어 회원가입 중복 확인 버튼을 입력창 옆에 붙이고,
마이페이지에 "내가 등록한 평점" 자식 화면(`/my/ratings`)을 추가했다.

```bash
cp .env.example .env   # TMDB_ACCESS_TOKEN 에 TMDB "API 읽기 액세스 토큰"(긴 값). .env 는 Git 제외
flutter pub get
flutter run -d chrome --web-port 5173   # 자체 백엔드 CORS 허용 출처와 같은 포트
flutter analyze
flutter test                            # 100개, 네트워크를 쓰지 않는다
MOVIELOG_LIVE=1 flutter test test/live   # 실제 TMDB·백엔드로 인증 화면·로그 생성(evidence/week05)
```

## 6주차 변경

| 위치 | 하는 일 |
|---|---|
| `widgets/movielog_button.dart` | 공용 버튼. 기본·통신 중·비활성 세 상태와 `width`(null / `double.infinity` / 고정) |
| `view_models/sign_up_view_model.dart` | `CheckStatus {idle, checking, available, duplicated, error}`를 닉네임·이메일에 따로 가진다. 입력이 바뀌면 이전 결과 무효화, 중복이었던 값은 기억해 같은 값을 다시 입력하면 서버에 묻지 않고 즉시 에러로 복원 |
| `features/sign_up/presentation/widgets/duplicate_check_field.dart` | 입력창 + 바깥 오른쪽(8px) `MovieLogButton`. 결과 문구는 `TextFormField.errorText`, 체크 표시는 입력창 안쪽 |
| `data/models/rating_with_movie.dart` | 자체 백엔드 평점 + TMDB 영화 한 쌍. TMDB에서 못 찾으면 `movie`가 null |
| `data/services/tmdb_movie_service.dart` | `findMovieById`: TMDB 404는 null, 그 밖의 오류는 던진다 |
| `view_models/my_ratings_view_model.dart` | memberId는 학습용 상수 `sampleMemberId = 1`. Loading/Empty/Error/Success, 영화 캐시(404는 캐시, 일시 실패는 재시도), 400·404·통신 실패 문구 분리 |
| `features/my_page/presentation/my_ratings_screen.dart` | "내가 등록한 평점" 화면. 하단 NavigationBar 없이 BackButton |
| `app/app_router.dart` | `/my/ratings`를 `parentNavigatorKey: rootNavigatorKey`로 root Navigator 위에 열어 NavigationBar를 가린다 |

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
- 회원가입: 닉네임(2~12자)·이메일 `중복 확인` → `GET /members/nickname|email/...`. 확인한 값 그대로여야 가입 버튼이 켜진다. 6주차: 버튼은 입력창 오른쪽, 중복이면 입력창이 에러 상태가 되고 버튼이 즉시 비활성, 입력을 바꾸면 해제, 방금 지운 중복 값을 다시 입력하면 요청 없이 즉시 에러.
- 마이페이지: "내가 등록한 평점" 행 → `/my/ratings`(`GET /members/1/ratings`, 로그인 전이라 시드 회원 1번) + movieId로 TMDB 제목·포스터. 평점이 없으면 Empty, 실패하면 Error(원인별 문구), TMDB 실패는 그 영화만 placeholder.
- 장르·정렬 저장 키는 `selected_genre_ids`(TMDB ID)·`movie_sort`. 4주차 이름 값은 읽지 않는다.

## 검증 자료 (`evidence/week05`)

- `web-signup-duplicate-check.jpg`, `web-my-ratings.jpg`: 실제 Chrome의 MovieLog 웹(5173)이 실제 NestJS 서버(3000)를 CORS 허용 상태로 호출한 화면
- `network-failure-log.txt`: 실제 TMDB에 잘못된 Token → 401, URL·오류는 남고 Token 원문은 없음, release 조건에선 0줄
- `12_empty_fixture.png`, `13_poster_placeholder_fixture.png`: 가짜 응답으로 만든 Empty·포스터 없음/로드 실패
- `01~11_*.png`, `network-log.txt`: `test/live/live_evidence_test.dart`가 실제 TMDB 응답으로 만든 화면(Token 필요)

## 검증 자료 (`evidence/week06`)

- `01~06_*.jpg`: 실제 NestJS(3000)에 연결한 Flutter Web(Chrome 390x844)의 중복 확인 화면. 사용 가능 · 중복 · 입력 수정 시 해제 · 지운 중복 값 재입력 시 즉시 에러 · 이메일 · 서버 꺼짐
- `07_bug_before_error_truncated.jpg`: 통신 실패 문구가 "다시 …"로 잘리던 수정 전 화면 (`errorMaxLines: 3`으로 수정, `06`이 수정 후)
- `08~09_*.jpg`: 마이페이지 진입 행과 "내가 등록한 평점"(실제 DB 평점 2개). 이 환경에는 TMDB Token이 없어 영화 제목·포스터는 placeholder
- `network-duplicate-check.txt`: 위 시나리오에서 실제로 나간 요청 기록
- `flutter-analyze.txt`, `flutter-test.txt`: 분석·테스트 결과
- 스크린샷은 한글 글꼴을 받지 못하는 환경이라 임시 복사본에 Pretendard를 붙여 빌드한 것으로 찍었다(저장소 코드에는 글꼴 변경 없음)
